import 'package:flutter/material.dart';
import '../models/glucose_reading.dart';

/// Widget que exibe o valor de glicemia com cor e label clínico.
class GlucoseIndicator extends StatelessWidget {
  final int value;
  final GlucoseStatus status;
  final bool large;

  const GlucoseIndicator({
    super.key,
    required this.value,
    required this.status,
    this.large = false,
  });

  Color _color(BuildContext context) {
    switch (status) {
      case GlucoseStatus.emergency: return Colors.red.shade900;
      case GlucoseStatus.low:       return Colors.red.shade600;
      case GlucoseStatus.normal:    return Colors.green.shade600;
      case GlucoseStatus.high:      return Colors.orange.shade700;
      case GlucoseStatus.veryHigh:  return Colors.red.shade700;
    }
  }

  String get _label {
    switch (status) {
      case GlucoseStatus.emergency: return 'EMERGÊNCIA';
      case GlucoseStatus.low:       return 'HIPOGLICEMIA';
      case GlucoseStatus.normal:    return 'NORMAL';
      case GlucoseStatus.high:      return 'ALTO';
      case GlucoseStatus.veryHigh:  return 'MUITO ALTO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final valueSize = large ? 72.0 : 48.0;
    final unitSize = large ? 18.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(' mg/dL',
                  style: TextStyle(
                      fontSize: unitSize,
                      color: color,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
