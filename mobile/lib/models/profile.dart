class Profile {
  final String id;
  final String name;
  final String diabetesType;
  final String? physicalLimitations;
  final int targetMin;
  final int targetMax;

  const Profile({
    required this.id,
    required this.name,
    required this.diabetesType,
    this.physicalLimitations,
    required this.targetMin,
    required this.targetMax,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      name: json['name'],
      diabetesType: json['diabetesType'] ?? 'NONE',
      physicalLimitations: json['physicalLimitations'],
      targetMin: json['targetMin'] ?? 70,
      targetMax: json['targetMax'] ?? 180,
    );
  }

  bool get isType1 => diabetesType == 'TYPE_1';
  bool get isPreDiabetes => diabetesType == 'PREDIABETES';

  String get diabetesTypeLabel {
    switch (diabetesType) {
      case 'TYPE_1':      return 'Diabetes Tipo 1';
      case 'TYPE_2':      return 'Diabetes Tipo 2';
      case 'PREDIABETES': return 'Pré-diabetes';
      default:            return 'Sem diagnóstico';
    }
  }
}
