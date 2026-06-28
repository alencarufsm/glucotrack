import 'package:flutter/foundation.dart';
import '../models/glucose_reading.dart';
import '../models/alert.dart';
import '../services/api_service.dart';

/// Gerencia a lista de medições e alertas do usuário logado.
class ReadingsProvider extends ChangeNotifier {
  final ApiService _api;

  List<GlucoseReading> _readings = [];
  List<GlucoAlert> _alerts = [];
  GlucoseReading? _latestReading;
  bool _loading = false;
  String? _error;

  ReadingsProvider(this._api);

  List<GlucoseReading> get readings => _readings;
  List<GlucoAlert> get alerts => _alerts;
  GlucoseReading? get latestReading => _latestReading;
  bool get loading => _loading;
  String? get error => _error;
  int get unreadAlertCount => _alerts.where((a) => !a.isRead).length;

  Future<void> loadLatestReading() async {
    try {
      _latestReading = await _api.getLatestReading();
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao carregar última medição';
      notifyListeners();
    }
  }

  Future<void> loadReadings({DateTime? from, DateTime? to}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _readings = await _api.getReadings(from: from, to: to);
    } catch (e) {
      _error = 'Erro ao carregar histórico';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<GlucoseReading?> addReading({
    required int value,
    required String mealContext,
    String? notes,
  }) async {
    try {
      final reading = await _api.createReading(
        value: value,
        mealContext: mealContext,
        notes: notes,
      );
      _latestReading = reading;
      _readings.insert(0, reading);
      notifyListeners();

      // Recarrega alertas para pegar novo alerta gerado pelo backend
      await loadAlerts();

      return reading;
    } catch (e) {
      _error = 'Erro ao registrar medição. Verifique sua conexão.';
      notifyListeners();
      return null;
    }
  }

  Future<void> loadAlerts() async {
    try {
      _alerts = await _api.getAlerts();
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
