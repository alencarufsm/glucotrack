import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/glucose_reading.dart';
import '../models/alert.dart';
import '../models/profile.dart';

/// Centraliza todas as chamadas HTTP para o backend Spring Boot.
/// Injeta automaticamente o JWT do Supabase em cada requisição.
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.backendUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor: adiciona o JWT do Supabase em todo request automaticamente
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // --- MEDIÇÕES ---

  Future<GlucoseReading> createReading({
    required int value,
    required String mealContext,
    String? notes,
    DateTime? measuredAt,
  }) async {
    final response = await _dio.post('/api/readings', data: {
      'value': value,
      'mealContext': mealContext,
      'notes': notes,
      'measuredAt': (measuredAt ?? DateTime.now()).toIso8601String(),
      'source': 'MANUAL',
    });
    return GlucoseReading.fromJson(response.data);
  }

  Future<List<GlucoseReading>> getReadings({
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, String>{};
    if (from != null) queryParams['from'] = from.toIso8601String();
    if (to != null) queryParams['to'] = to.toIso8601String();

    final response = await _dio.get('/api/readings', queryParameters: queryParams);
    return (response.data as List).map((j) => GlucoseReading.fromJson(j)).toList();
  }

  Future<GlucoseReading?> getLatestReading() async {
    try {
      final response = await _dio.get('/api/readings/latest');
      return GlucoseReading.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // --- PERFIL ---

  Future<Profile> getProfile() async {
    final response = await _dio.get('/api/users/me');
    return Profile.fromJson(response.data);
  }

  Future<Profile> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.put('/api/users/me', data: data);
    return Profile.fromJson(response.data);
  }

  // --- ALERTAS ---

  Future<List<GlucoAlert>> getAlerts() async {
    final response = await _dio.get('/api/alerts');
    return (response.data as List).map((j) => GlucoAlert.fromJson(j)).toList();
  }

  Future<List<GlucoAlert>> getUnreadAlerts() async {
    final response = await _dio.get('/api/alerts/unread');
    return (response.data as List).map((j) => GlucoAlert.fromJson(j)).toList();
  }

  // --- CONEXÕES FAMILIARES ---

  Future<void> inviteFamilyMember(String observerUserId) async {
    await _dio.post('/api/family/invite', data: {'observerUserId': observerUserId});
  }

  Future<void> acceptInvite(String connectionId) async {
    await _dio.put('/api/family/invite/$connectionId/accept');
  }
}
