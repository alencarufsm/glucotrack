class GlucoseReading {
  final String id;
  final int value;
  final DateTime measuredAt;
  final String mealContext;
  final String source;
  final String? notes;
  final String glucoseLevel;

  const GlucoseReading({
    required this.id,
    required this.value,
    required this.measuredAt,
    required this.mealContext,
    required this.source,
    this.notes,
    required this.glucoseLevel,
  });

  factory GlucoseReading.fromJson(Map<String, dynamic> json) {
    return GlucoseReading(
      id: json['id'],
      value: json['value'],
      measuredAt: DateTime.parse(json['measuredAt']),
      mealContext: json['mealContext'] ?? 'OTHER',
      source: json['source'] ?? 'MANUAL',
      notes: json['notes'],
      glucoseLevel: json['glucoseLevel'] ?? 'NORMAL',
    );
  }

  /// Cor associada ao nível de glicemia para exibição na UI
  GlucoseStatus get status {
    switch (glucoseLevel) {
      case 'HYPOGLYCEMIA_SEVERE':
        return GlucoseStatus.emergency;
      case 'HYPOGLYCEMIA':
        return GlucoseStatus.low;
      case 'HYPERGLYCEMIA':
        return GlucoseStatus.high;
      case 'HYPERGLYCEMIA_SEVERE':
        return GlucoseStatus.veryHigh;
      default:
        return GlucoseStatus.normal;
    }
  }

  String get mealContextLabel {
    switch (mealContext) {
      case 'FASTING':    return 'Jejum';
      case 'PRE_MEAL':   return 'Pré-refeição';
      case 'POST_MEAL':  return 'Pós-refeição';
      case 'BEDTIME':    return 'Antes de dormir';
      default:           return 'Outro momento';
    }
  }
}

enum GlucoseStatus { emergency, low, normal, high, veryHigh }
