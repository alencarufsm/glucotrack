import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

// ─────────────────────────── Models ───────────────────────────

class LibreNfcData {
  /// UID do sensor (8 bytes, lido via ISO 15693 / NFC-V).
  /// Serve de base para derivar a chave BLE de autenticação/decriptação.
  final Uint8List sensorUid;

  /// Serial legível (extraído do UID — últimos 4 bytes em hex).
  final String serialHint;

  /// Informações do patch/sensor da Abbott (7 bytes, comando 0xA1).
  /// Null se o comando customizado não for suportado.
  final Uint8List? patchInfo;

  const LibreNfcData({
    required this.sensorUid,
    required this.serialHint,
    this.patchInfo,
  });

  @override
  String toString() =>
      'LibreNfcData(uid=${_hex(sensorUid)}, serial=$serialHint)';

  static String _hex(Uint8List b) =>
      b.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
}

// ─────────────────────── LibreNfcService ──────────────────────

/// Leitura do sensor FreeStyle Libre 2 Plus via NFC (ISO 15693 / NFC-V).
///
/// O sensor precisa ser tocado / aproximado muito próximo do celular.
/// Isso lê o UID único do sensor que é usado para:
///   1. Derivar a chave AES-128 para autenticação BLE
///   2. Decriptar os frames de glicose recebidos via Bluetooth
///
/// Após o toque NFC, o sensor inicia (ou confirma) a transmissão BLE.
///
/// Referências open-source:
///   • Juggluco:      https://www.juggluco.nl/Juggluco/src.html
///   • LibreMonitor:  https://github.com/dabear/LibreMonitor
///   • xDrip+:        https://github.com/NightscoutFoundation/xDrip
class LibreNfcService {
  static bool _available = false;

  static Future<bool> isAvailable() async {
    _available = await NfcManager.instance.isAvailable();
    return _available;
  }

  /// Inicia uma sessão NFC e aguarda o toque no sensor Libre.
  ///
  /// Chame [stopSession] para cancelar antes do toque.
  /// A mensagem [alertMessage] aparece na UI do sistema no iOS.
  Future<LibreNfcData> readSensor({
    String alertMessage = 'Aproxime o celular do sensor FreeStyle Libre',
  }) {
    final completer = Completer<LibreNfcData>();

    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092, // fallback
      },
      alertMessage: alertMessage,
      onDiscovered: (NfcTag tag) async {
        try {
          final data = await _processTag(tag);
          await NfcManager.instance.stopSession(alertMessage: 'Sensor lido!');
          completer.complete(data);
        } catch (e) {
          await NfcManager.instance.stopSession(
            errorMessage: 'Erro: ${e.toString().replaceFirst("Exception: ", "")}',
          );
          completer.completeError(e);
        }
      },
    );

    return completer.future;
  }

  Future<void> stopSession() async {
    await NfcManager.instance.stopSession();
  }

  // ── Tag processing ─────────────────────────────────────────

  Future<LibreNfcData> _processTag(NfcTag tag) async {
    final uid = _extractUid(tag);
    if (uid == null) {
      throw Exception(
        'Tag NFC não reconhecida como sensor FreeStyle Libre. '
        'Certifique-se de tocar diretamente no sensor.',
      );
    }

    Uint8List? patchInfo;
    try {
      patchInfo = await _readPatchInfo(tag, uid);
    } catch (_) {
      // getPatchInfo é opcional — o UID sozinho já serve para derivar a chave
    }

    final serialHint = _uidToSerialHint(uid);

    return LibreNfcData(
      sensorUid: uid,
      serialHint: serialHint,
      patchInfo: patchInfo,
    );
  }

  /// Extrai o UID (8 bytes) do tag ISO 15693 / NFC-V.
  ///
  /// O UID retornado pelo hardware vem em little-endian (invertido);
  /// revertemos para obter a representação correta do serial Abbott.
  Uint8List? _extractUid(NfcTag tag) {
    final data = tag.data;

    // iOS: NFCISo15693Tag → campo "nfciso15693tag"
    if (Platform.isIOS) {
      final isoData = data['nfciso15693tag'] as Map<dynamic, dynamic>?;
      final id = isoData?['identifier'] as List<dynamic>?;
      if (id != null && id.length == 8) {
        return Uint8List.fromList(id.cast<int>().reversed.toList());
      }
    }

    // Android: NfcV → campo "nfcv"
    final nfcvData = data['nfcv'] as Map<dynamic, dynamic>?;
    final idNfcV = nfcvData?['identifier'] as List<dynamic>?;
    if (idNfcV != null && idNfcV.length == 8) {
      return Uint8List.fromList(idNfcV.cast<int>().reversed.toList());
    }

    // Fallback genérico
    final idGeneric = data['identifier'] as List<dynamic>?;
    if (idGeneric != null && idGeneric.length == 8) {
      return Uint8List.fromList(idGeneric.cast<int>().reversed.toList());
    }

    return null;
  }

  /// Comando customizado Abbott 0xA1 (Get Patch Info).
  /// Retorna 7 bytes com tipo de sensor, versão de firmware e flags.
  Future<Uint8List?> _readPatchInfo(NfcTag tag, Uint8List uid) async {
    if (Platform.isIOS) {
      final iso = Iso15693.from(tag);
      if (iso == null) return null;

      final response = await iso.customCommand(
        requestFlags: {Iso15693RequestFlag.highDataRate},
        customCommandCode: 0xA1,
        customRequestParameters: Uint8List.fromList([0x07]),
      );
      // Response[0] é o byte de status — ignora; restante é o patchInfo
      if (response.length >= 8) {
        return Uint8List.fromList(response.sublist(1));
      }
      return null;
    }

    // Android: envia via transceive (NFC-V raw command)
    final nfcv = NfcV.from(tag);
    if (nfcv == null) return null;

    // Frame ISO 15693: [flags, cmd, UID(8), param]
    final cmd = Uint8List.fromList([
      0x02,       // flags: high data rate
      0xA1,       // Abbott custom command
      ...uid.reversed, // UID em little-endian
      0x07,
    ]);

    final response = await nfcv.transceive(data: cmd);
    if (response.length >= 8) {
      return Uint8List.fromList(response.sublist(1));
    }
    return null;
  }

  // ── UID helpers ────────────────────────────────────────────

  /// Últimos 4 bytes do UID em hex — suficiente para identificar o sensor.
  String _uidToSerialHint(Uint8List uid) {
    return uid
        .sublist(uid.length - 4)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
  }

  // ── Key derivation ──────────────────────────────────────────

  /// Deriva a chave AES-128 para autenticação/decriptação BLE.
  ///
  /// O Libre 2 usa o UID do sensor (8 bytes) como base da chave:
  ///   key = UID invertido (8 bytes) + UID invertido (8 bytes) = 16 bytes
  ///
  /// Esta é a derivação documentada em Juggluco (Libre2Crypt.java).
  static Uint8List deriveKey(Uint8List sensorUid) {
    final reversed = Uint8List.fromList(sensorUid.reversed.toList());
    final key = Uint8List(16);
    key.setRange(0, 8, reversed);
    key.setRange(8, 16, reversed);
    return key;
  }
}
