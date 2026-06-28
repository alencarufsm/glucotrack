class GlucoAlert {
  final String id;
  final String alertType;
  final String severity;
  final int? glucoseValue;
  final String message;
  final bool isRead;
  final DateTime triggeredAt;

  const GlucoAlert({
    required this.id,
    required this.alertType,
    required this.severity,
    this.glucoseValue,
    required this.message,
    required this.isRead,
    required this.triggeredAt,
  });

  factory GlucoAlert.fromJson(Map<String, dynamic> json) {
    return GlucoAlert(
      id: json['id'],
      alertType: json['alertType'],
      severity: json['severity'],
      glucoseValue: json['glucoseValue'],
      message: json['message'],
      isRead: json['isRead'] ?? false,
      triggeredAt: DateTime.parse(json['triggeredAt']),
    );
  }

  bool get isEmergency => severity == 'EMERGENCY';
  bool get isCritical  => severity == 'CRITICAL';
}
