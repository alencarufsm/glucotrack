import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import '../services/libre_ble_service.dart';
import '../services/libre_nfc_service.dart';

export '../services/libre_ble_service.dart'
    show LibreSensorDevice, LibreGlucoseFrame, LibreBleConnectionState;

class LibreBleProvider extends ChangeNotifier {
  static const _keySensorId = 'libre_ble_sensor_id';
  static const _keySensorName = 'libre_ble_sensor_name';
  // UID do sensor salvo como lista de bytes em base64
  static const _keyUid = 'libre_ble_uid';

  final ApiService _apiService;
  final LibreBleService _ble = LibreBleService();
  final _storage = const FlutterSecureStorage();

  LibreBleConnectionState _state = LibreBleConnectionState.idle;
  String? _connectedSensorName;
  String? _savedSensorId;
  String? _error;
  LibreGlucoseFrame? _lastReading;
  bool _isConfigured = false;

  StreamSubscription<LibreBleConnectionState>? _stateSub;
  StreamSubscription<LibreGlucoseFrame>? _glucoseSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  LibreBleProvider(this._apiService);

  LibreBleConnectionState get state => _state;
  String? get connectedSensorName => _connectedSensorName;
  String? get error => _error;
  LibreGlucoseFrame? get lastReading => _lastReading;
  bool get isConfigured => _isConfigured;
  bool get isConnected => _state == LibreBleConnectionState.connected;

  Future<void> initialize() async {
    _savedSensorId = await _storage.read(key: _keySensorId);
    _connectedSensorName = await _storage.read(key: _keySensorName);
    _isConfigured = _savedSensorId != null;

    // Restaura o UID salvo para uso em reconexões
    final uidStr = await _storage.read(key: _keyUid);
    if (uidStr != null) {
      final uid = Uint8List.fromList(
        uidStr.split(',').map(int.parse).toList(),
      );
      _ble.setSensorUid(uid);
    }

    _stateSub = _ble.stateStream.listen((s) {
      _state = s;
      notifyListeners();
    });

    _glucoseSub = _ble.glucoseStream.listen((frame) async {
      _lastReading = frame;
      notifyListeners();
      await _saveReading(frame);
    });
  }

  // ── Fluxo principal: NFC → BLE ────────────────────────────

  /// Chamado pela LibreNfcConnectScreen após o toque NFC bem-sucedido.
  ///
  /// 1. Salva o UID do sensor
  /// 2. Escaneia BLE por até 15s buscando "ABBOTT{serial}"
  /// 3. Conecta automaticamente ao primeiro sensor encontrado
  Future<void> startScanAndConnectWithUid(LibreNfcData nfcData) async {
    _error = null;
    _state = LibreBleConnectionState.scanning;
    notifyListeners();

    // Passa o UID para o serviço BLE (deriva a chave AES)
    _ble.setSensorUid(nfcData.sensorUid);

    // Persiste o UID para reconexões futuras
    await _storage.write(
      key: _keyUid,
      value: nfcData.sensorUid.join(','),
    );

    // Escaneia buscando o sensor pelo nome BLE (ABBOTT + serial do UID)
    LibreSensorDevice? found;

    final scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName;
        if (name.startsWith('ABBOTT') ||
            r.advertisementData.manufacturerData.containsKey(0x0308)) {
          final hint = name.length > 6 ? name.substring(6) : null;
          found = LibreSensorDevice(device: r.device, serialHint: hint);
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withNames: ['ABBOTT'],
      timeout: const Duration(seconds: 15),
      androidUsesFineLocation: false,
    );

    await scanSub.cancel();

    if (found == null) {
      _error =
          'Sensor não encontrado via Bluetooth. Certifique-se de que o LibreLink '
          'está fechado e o sensor está próximo.';
      _state = LibreBleConnectionState.error;
      notifyListeners();
      return;
    }

    await _connectDevice(found!);
  }

  Future<void> _connectDevice(LibreSensorDevice sensor) async {
    _state = LibreBleConnectionState.connecting;
    notifyListeners();

    try {
      await _ble.connect(sensor);
      _connectedSensorName = sensor.displayName;
      _savedSensorId = sensor.id;
      _isConfigured = true;
      await _storage.write(key: _keySensorId, value: sensor.id);
      await _storage.write(key: _keySensorName, value: sensor.displayName);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _state = LibreBleConnectionState.error;
    }

    notifyListeners();
  }

  // ── Disconnect / clear ────────────────────────────────────

  Future<void> disconnect() async {
    await _ble.disconnect();
    _state = LibreBleConnectionState.disconnected;
    notifyListeners();
  }

  Future<void> clearConfiguration() async {
    await disconnect();
    await _storage.delete(key: _keySensorId);
    await _storage.delete(key: _keySensorName);
    await _storage.delete(key: _keyUid);
    _isConfigured = false;
    _connectedSensorName = null;
    _savedSensorId = null;
    _lastReading = null;
    _state = LibreBleConnectionState.idle;
    notifyListeners();
  }

  // ── Persist reading ───────────────────────────────────────

  Future<void> _saveReading(LibreGlucoseFrame frame) async {
    try {
      await _apiService.createReading(
        value: frame.valueInMgDl,
        mealContext: 'OTHER',
        measuredAt: frame.timestamp,
        source: 'LIBRE',
      );
    } catch (_) {}
  }

  // ── Trend arrow ───────────────────────────────────────────

  String trendArrow(double trend) {
    if (trend > 2) return '↑↑';
    if (trend > 1) return '↑';
    if (trend > 0.3) return '↗';
    if (trend >= -0.3) return '→';
    if (trend >= -1) return '↘';
    if (trend >= -2) return '↓';
    return '↓↓';
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _glucoseSub?.cancel();
    _scanSub?.cancel();
    _ble.dispose();
    super.dispose();
  }
}
