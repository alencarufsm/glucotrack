import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/librelink_service.dart';
import '../services/api_service.dart';

class LibreLinkProvider extends ChangeNotifier {
  static const _keyEmail = 'libre_email';
  static const _keyPassword = 'libre_password';
  static const _keyPatientId = 'libre_patient_id';
  static const _keyPatientName = 'libre_patient_name';

  final ApiService _apiService;
  final LibreLinkService _libre = LibreLinkService();
  final _storage = const FlutterSecureStorage();

  bool _isConfigured = false;
  bool _isSyncing = false;
  DateTime? _lastSync;
  String? _patientName;
  String? _error;

  LibreLinkProvider(this._apiService);

  bool get isConfigured => _isConfigured;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSync => _lastSync;
  String? get patientName => _patientName;
  String? get error => _error;

  Future<void> initialize() async {
    final email = await _storage.read(key: _keyEmail);
    _isConfigured = email != null;
    _patientName = await _storage.read(key: _keyPatientName);
    notifyListeners();
  }

  Future<void> configure({
    required String email,
    required String password,
    required String patientId,
    required String patientName,
  }) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyPatientId, value: patientId);
    await _storage.write(key: _keyPatientName, value: patientName);
    _isConfigured = true;
    _patientName = patientName;
    _error = null;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _storage.deleteAll();
    _isConfigured = false;
    _patientName = null;
    _lastSync = null;
    _error = null;
    notifyListeners();
  }

  /// Autentica com as credenciais salvas e retorna a sessão.
  Future<LibreLinkSession> _authenticate() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    if (email == null || password == null) {
      throw Exception('Credenciais não configuradas');
    }
    return _libre.login(email, password);
  }

  /// Busca leituras da LibreLink e envia ao backend GlicoTrack.
  /// Retorna o número de leituras enviadas com sucesso.
  Future<int> sync() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _authenticate();
      final patientId = await _storage.read(key: _keyPatientId);
      if (patientId == null) throw Exception('Paciente não configurado');

      final readings = await _libre.getReadings(session, patientId);

      int saved = 0;
      for (final r in readings) {
        try {
          await _apiService.createReading(
            value: r.valueInMgDl,
            mealContext: 'OTHER',
            measuredAt: r.timestamp,
            source: 'LIBRE',
          );
          saved++;
        } catch (_) {
          // Leitura já existente ou erro pontual — continua para as demais
        }
      }

      _lastSync = DateTime.now();
      return saved;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Usado pela tela de configuração para testar credenciais antes de salvar.
  Future<({LibreLinkSession session, List<LibreConnection> connections})>
      testCredentials(String email, String password) async {
    final session = await _libre.login(email, password);
    final connections = await _libre.getConnections(session);
    return (session: session, connections: connections);
  }
}
