import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'libre_nfc_service.dart';

// ───────────────────────── Models ─────────────────────────

class LibreSensorDevice {
  final BluetoothDevice device;

  // Últimos 4 chars do serial extraídos do nome BLE (ex.: "FSL-XXXX")
  final String? serialHint;

  const LibreSensorDevice({required this.device, this.serialHint});

  String get id => device.remoteId.str;

  String get displayName {
    final name = device.platformName;
    return name.isNotEmpty ? name : id;
  }

  int get rssi => -999; // atualizado via ScanResult no provider
}

class LibreGlucoseFrame {
  final int valueInMgDl;
  final DateTime timestamp;

  // Taxa de variação em mg/dL por minuto (positivo = subindo, negativo = descendo)
  final double trendPerMinute;

  const LibreGlucoseFrame({
    required this.valueInMgDl,
    required this.timestamp,
    required this.trendPerMinute,
  });
}

enum LibreBleConnectionState {
  idle,
  scanning,
  connecting,
  authenticating,
  connected,
  disconnected,
  error,
}

// ──────────────────── BLE UUIDs (Libre 2) ──────────────────────
//
// Protocolo reverso-engenheirado pela comunidade open-source.
// Referências:
//   • Juggluco:       https://www.juggluco.nl/Juggluco/src.html
//   • LibreMonitor:   https://github.com/dabear/LibreMonitor
//   • xDrip+:         https://github.com/NightscoutFoundation/xDrip
//
// Os UUIDs abaixo correspondem ao FreeStyle Libre 2 (EU/US).
// Libre 2 Plus usa o mesmo serviço primário com características adicionais.
// ───────────────────────────────────────────────────────────────

const _serviceUuid = '089810CC-EF89-11E9-81B4-2A2AE2DBCCE4';

// Característica de autenticação: challenge/response AES-128
const _authCharUuid = 'F001B612-9BD7-4B5F-9B31-C78FE6A97396';

// Característica de medição de glicose: notificações a cada ~1 min
const _glucoseCharUuid = 'F002B612-9BD7-4B5F-9B31-C78FE6A97396';

// Manufacturer ID da Abbott no BLE advertisement (0x0308 = 776)
const _abbottManufacturerId = 0x0308;

// ──────────────────── LibreBleService ────────────────────────

/// Leitura direta do FreeStyle Libre 2 Plus via Bluetooth LE.
///
/// IMPORTANTE: O sensor mantém conexão EXCLUSIVA com um único app.
/// Enquanto este app estiver conectado, o LibreLink deve estar fechado
/// no mesmo celular (ou o sensor deve estar próximo a este dispositivo).
class LibreBleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _authChar;
  BluetoothCharacteristic? _glucoseChar;
  StreamSubscription<List<int>>? _glucoseSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  /// UID do sensor (8 bytes), obtido via NFC.
  /// Usado para derivar a chave AES de autenticação/decriptação BLE.
  Uint8List? _sensorUid;

  final _glucoseController =
      StreamController<LibreGlucoseFrame>.broadcast();
  final _stateController =
      StreamController<LibreBleConnectionState>.broadcast();

  Stream<LibreGlucoseFrame> get glucoseStream => _glucoseController.stream;
  Stream<LibreBleConnectionState> get stateStream => _stateController.stream;

  bool get isConnected => _device != null;

  void setSensorUid(Uint8List uid) {
    _sensorUid = uid;
  }

  // ── Scan ──────────────────────────────────────────────────

  /// Escaneia sensores Libre nas proximidades e emite cada um encontrado.
  /// Filtra por nome de dispositivo ("FSL") e/ou pelo Manufacturer ID Abbott.
  Stream<({LibreSensorDevice sensor, int rssi})> scanForSensors({
    Duration timeout = const Duration(seconds: 20),
  }) async* {
    _stateController.add(LibreBleConnectionState.scanning);

    final seen = <String>{};

    await for (final results in FlutterBluePlus.scanResults
        .timeout(timeout, onTimeout: (_) {})) {
      for (final r in results) {
        if (!_isLibreSensor(r)) continue;
        if (seen.contains(r.device.remoteId.str)) continue;
        seen.add(r.device.remoteId.str);

        final hint = _extractSerialHint(r.device.platformName);
        final sensor = LibreSensorDevice(
          device: r.device,
          serialHint: hint,
        );
        yield (sensor: sensor, rssi: r.rssi);
      }
    }

    if (_stateController.hasListener) {
      _stateController.add(LibreBleConnectionState.idle);
    }
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 20)}) {
    return FlutterBluePlus.startScan(
      withNames: ['ABBOTT'],
      timeout: timeout,
      androidUsesFineLocation: false,
    );
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  // ── Connect ───────────────────────────────────────────────

  Future<void> connect(LibreSensorDevice sensor) async {
    await disconnect();

    _device = sensor.device;
    _stateController.add(LibreBleConnectionState.connecting);

    // Monitora desconexão inesperada
    _connectionSub = sensor.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _cleanupConnection();
        _stateController.add(LibreBleConnectionState.disconnected);
      }
    });

    await sensor.device.connect(
      timeout: const Duration(seconds: 15),
      autoConnect: false,
    );

    final services = await sensor.device.discoverServices();

    final service = services.cast<BluetoothService?>().firstWhere(
          (s) =>
              s!.uuid.toString().toUpperCase() == _serviceUuid.toUpperCase(),
          orElse: () => null,
        );

    if (service == null) {
      await disconnect();
      throw Exception(
        'Serviço Libre não encontrado. '
        'Verifique se o sensor é um FreeStyle Libre 2 Plus.',
      );
    }

    _authChar = _findChar(service, _authCharUuid);
    _glucoseChar = _findChar(service, _glucoseCharUuid);

    _stateController.add(LibreBleConnectionState.authenticating);
    await _authenticate();

    await _subscribeToGlucose();
    _stateController.add(LibreBleConnectionState.connected);
  }

  BluetoothCharacteristic? _findChar(BluetoothService s, String uuid) =>
      s.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
            (c) => c!.uuid.toString().toUpperCase() == uuid.toUpperCase(),
            orElse: () => null,
          );

  // ── Authentication ─────────────────────────────────────────
  //
  // Protocolo Libre 2 (AES-128-CTR, chave derivada do serial):
  //
  //  1. App escreve [0x01] na auth characteristic (solicita challenge)
  //  2. Sensor notifica 8 bytes de challenge
  //  3. App deriva chave AES-128 a partir do serial do sensor
  //  4. App criptografa challenge com AES-128-CTR e envia resultado
  //  5. Sensor responde [0x04, 0x01] se autenticado, [0x04, 0x00] se falhou
  //
  // Referência de implementação:
  //   Juggluco — LibreAuth.java / authenticate()
  //   LibreMonitor — LibreUtils.swift / authenticateSession()

  Future<void> _authenticate() async {
    if (_authChar == null) return; // sensor pode não exigir auth (alguns Libre 1)

    // Etapa 1: solicita challenge
    await _authChar!.write([0x01], withoutResponse: false);
    await _authChar!.setNotifyValue(true);

    // Etapa 2: aguarda 8 bytes de challenge
    final challenge = await _authChar!.lastValueStream
        .where((v) => v.isNotEmpty)
        .first
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw Exception('Timeout aguardando challenge do sensor'),
        );

    // Etapa 3-4: deriva chave e envia resposta
    final response = _buildAuthResponse(Uint8List.fromList(challenge));
    await _authChar!.write(response, withoutResponse: false);

    // Etapa 5: aguarda confirmação
    final confirm = await _authChar!.lastValueStream
        .where((v) => v.isNotEmpty)
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              throw Exception('Timeout aguardando confirmação de autenticação'),
        );

    await _authChar!.setNotifyValue(false);

    if (confirm.length < 2 || confirm[0] != 0x04 || confirm[1] != 0x01) {
      throw Exception(
        'Autenticação com o sensor falhou. '
        'Toque o celular no sensor novamente para reiniciar a sessão.',
      );
    }
  }

  /// Constrói a resposta de autenticação usando a chave derivada do UID NFC.
  ///
  /// Protocolo Libre 2 (Juggluco — Libre2Crypt.java):
  ///   key  = UID invertido (8 bytes) repetido duas vezes → 16 bytes AES-128
  ///   resp = AES-128-CTR(key, challenge)
  ///
  /// TODO: substituir _aes128Ctr() por implementação AES real.
  /// Adicione 'encrypt: ^5.0.3' ao pubspec.yaml e use:
  ///   final enc = Encrypter(AES(Key(key), mode: AESMode.ctr, padding: null));
  ///   return enc.encryptBytes(challenge, iv: IV(challenge)).bytes;
  Uint8List _buildAuthResponse(Uint8List challenge) {
    if (_sensorUid == null) {
      throw Exception(
        'UID do sensor não disponível. '
        'Toque o celular no sensor para iniciar a sessão NFC primeiro.',
      );
    }
    final key = LibreNfcService.deriveKey(_sensorUid!);
    return _aes128Ctr(key, challenge);
  }

  /// Placeholder AES-128-CTR — substituir pela implementação real.
  /// Veja o TODO em _buildAuthResponse().
  Uint8List _aes128Ctr(Uint8List key, Uint8List nonce) {
    final out = Uint8List(nonce.length);
    for (var i = 0; i < nonce.length; i++) {
      out[i] = nonce[i] ^ (i < key.length ? key[i] : 0);
    }
    return out;
  }

  // ── Glucose subscription ───────────────────────────────────

  Future<void> _subscribeToGlucose() async {
    if (_glucoseChar == null) return;

    await _glucoseChar!.setNotifyValue(true);
    _glucoseSub = _glucoseChar!.lastValueStream.listen((frame) {
      final reading = _decodeGlucoseFrame(Uint8List.fromList(frame));
      if (reading != null) _glucoseController.add(reading);
    });
  }

  /// Decodifica o frame de 8+ bytes de glicose do sensor.
  ///
  /// Frame format (após decriptação AES):
  ///   Bytes 0-1: valor bruto mg/dL (little-endian uint16)
  ///   Bytes 2-3: trend (little-endian int16, mg/dL/min × 10)
  ///   Bytes 4-7: timestamp relativo (minutos desde ativação)
  ///
  /// Nota: em produção os frames chegam criptografados via AES-CTR.
  /// A decriptação usa a mesma chave derivada do serial.
  LibreGlucoseFrame? _decodeGlucoseFrame(Uint8List frame) {
    if (frame.length < 4) return null;

    try {
      // TODO: descriptografar frame com AES-CTR antes de decodificar
      final rawMgDl = (frame[0] | (frame[1] << 8));
      final rawTrend = (frame[2] | (frame[3] << 8));
      final trend = rawTrend.toSigned(16) / 10.0;

      // Valores fisiologicamente impossíveis indicam frame inválido/não decriptado
      if (rawMgDl < 40 || rawMgDl > 500) return null;

      return LibreGlucoseFrame(
        valueInMgDl: rawMgDl,
        timestamp: DateTime.now(),
        trendPerMinute: trend,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Disconnect ─────────────────────────────────────────────

  Future<void> disconnect() async {
    await _glucoseSub?.cancel();
    _glucoseSub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;

    try {
      await _glucoseChar?.setNotifyValue(false);
    } catch (_) {}
    try {
      await _authChar?.setNotifyValue(false);
    } catch (_) {}

    try {
      await _device?.disconnect();
    } catch (_) {}

    _cleanupConnection();
  }

  void _cleanupConnection() {
    _device = null;
    _authChar = null;
    _glucoseChar = null;
  }

  bool _isLibreSensor(ScanResult r) {
    // Nome BLE real do FreeStyle Libre 2 Plus: "ABBOTT" + serial
    // Confirmado em hardware: "ABBOTT3MH01M9M1XW"
    if (r.device.platformName.startsWith('ABBOTT')) return true;
    return r.advertisementData.manufacturerData
        .containsKey(_abbottManufacturerId);
  }

  String? _extractSerialHint(String deviceName) {
    // Formato confirmado: "ABBOTT3MH01M9M1XW" → serial = "3MH01M9M1XW"
    if (deviceName.startsWith('ABBOTT') && deviceName.length > 6) {
      return deviceName.substring(6);
    }
    return null;
  }

  void dispose() {
    disconnect();
    _glucoseController.close();
    _stateController.close();
  }
}
