import 'package:dio/dio.dart';

class LibreLinkSession {
  final String token;
  final String accountId;
  final String baseUrl;

  const LibreLinkSession({
    required this.token,
    required this.accountId,
    required this.baseUrl,
  });
}

class LibreConnection {
  final String patientId;
  final String firstName;
  final String lastName;

  const LibreConnection({
    required this.patientId,
    required this.firstName,
    required this.lastName,
  });

  String get displayName => '$firstName $lastName'.trim();
}

class LibreReading {
  final int valueInMgDl;
  final DateTime timestamp;

  const LibreReading({required this.valueInMgDl, required this.timestamp});
}

/// Cliente para a LibreLink Up API (Abbott).
/// Protocolo documentado pela comunidade open-source (xDrip+, Juggluco).
class LibreLinkService {
  static const _defaultBaseUrl = 'https://api.libreview.io';

  static const _baseHeaders = {
    'product': 'llu.ios',
    'version': '4.7.0',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  final Dio _dio = Dio();

  Future<LibreLinkSession> login(String email, String password) async {
    var baseUrl = _defaultBaseUrl;

    var body = await _postLogin(baseUrl, email, password);

    // status 2 = precisa redirecionar para o servidor regional
    if (body['status'] == 2) {
      final region = body['data']?['region'] as String?;
      if (region == null) throw Exception('Região LibreLink não identificada');
      baseUrl = 'https://api-$region.libreview.io';
      body = await _postLogin(baseUrl, email, password);
    }

    if (body['status'] != 0) {
      final msg = body['error']?['message'] ?? 'Credenciais inválidas';
      throw Exception(msg);
    }

    final data = body['data'] as Map<String, dynamic>;
    final authTicket = data['authTicket'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;

    return LibreLinkSession(
      token: authTicket['token'] as String,
      accountId: user['id'] as String,
      baseUrl: baseUrl,
    );
  }

  Future<Map<String, dynamic>> _postLogin(
      String baseUrl, String email, String password) async {
    final response = await _dio.post(
      '$baseUrl/llu/auth/login',
      data: {'email': email, 'password': password},
      options: Options(
        headers: _baseHeaders,
        validateStatus: (_) => true,
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<LibreConnection>> getConnections(LibreLinkSession session) async {
    final response = await _dio.get(
      '${session.baseUrl}/llu/connections',
      options: Options(headers: _authHeaders(session)),
    );

    final body = response.data as Map<String, dynamic>;
    if (body['status'] != 0) throw Exception('Erro ao buscar conexões LibreLink');

    final list = body['data'] as List? ?? [];
    return list
        .map((c) => LibreConnection(
              patientId: c['patientId'] as String,
              firstName: c['firstName'] as String? ?? '',
              lastName: c['lastName'] as String? ?? '',
            ))
        .toList();
  }

  Future<List<LibreReading>> getReadings(
      LibreLinkSession session, String patientId) async {
    final response = await _dio.get(
      '${session.baseUrl}/llu/connections/$patientId/graph',
      options: Options(headers: _authHeaders(session)),
    );

    final body = response.data as Map<String, dynamic>;
    if (body['status'] != 0) throw Exception('Erro ao buscar leituras LibreLink');

    final graph = body['data']?['graphData'] as List? ?? [];

    // Também inclui a leitura atual do sensor se disponível
    final currentMeasurement =
        body['data']?['connection']?['glucoseMeasurement'];
    final all = [...graph, ?currentMeasurement];

    return all
        .map((r) => _parseReading(r as Map<String, dynamic>))
        .where((r) => r != null)
        .cast<LibreReading>()
        .toList();
  }

  LibreReading? _parseReading(Map<String, dynamic> r) {
    try {
      // Prefere mg/dL direto; fallback: converte mmol/L × 18.02
      final int value = (r['ValueInMgPerDl'] as num?)?.toInt() ??
          ((r['Value'] as num) * 18.02).round();

      final ts = r['FactoryTimestamp'] as String? ?? r['Timestamp'] as String;
      final timestamp = _parseTimestamp(ts);

      return LibreReading(valueInMgDl: value, timestamp: timestamp);
    } catch (_) {
      return null;
    }
  }

  /// Suporta os formatos de timestamp que a API Abbott retorna:
  /// ISO 8601 ou "M/D/YYYY h:mm:ss AM/PM"
  DateTime _parseTimestamp(String ts) {
    try {
      return DateTime.parse(ts).toLocal();
    } catch (_) {}

    // Formato: "6/28/2026 10:30:00 AM" ou "6/28/2026 22:30:00"
    final parts = ts.trim().split(' ');
    final dateParts = parts[0].split('/');
    final timeParts = parts[1].split(':');

    var hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final second = int.parse(timeParts[2]);

    if (parts.length == 3) {
      final isPm = parts[2].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
    }

    return DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      hour,
      minute,
      second,
    );
  }

  Map<String, String> _authHeaders(LibreLinkSession session) => {
        ..._baseHeaders,
        'Authorization': 'Bearer ${session.token}',
        'Account-Id': session.accountId,
      };
}
