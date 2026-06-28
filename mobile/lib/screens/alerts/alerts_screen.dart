import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/alert.dart';
import '../../providers/readings_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReadingsProvider>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final readings = context.watch<ReadingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Alertas')),
      body: readings.loading
          ? const Center(child: CircularProgressIndicator())
          : readings.alerts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Nenhum alerta registrado'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: readings.alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _AlertCard(alert: readings.alerts[i]),
                ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final GlucoAlert alert;

  const _AlertCard({required this.alert});

  Color get _color {
    if (alert.isEmergency) return Colors.red.shade900;
    if (alert.isCritical) return Colors.red.shade600;
    if (alert.severity == 'WARNING') return Colors.orange.shade700;
    return Colors.blue.shade600;
  }

  IconData get _icon {
    if (alert.isEmergency || alert.isCritical) return Icons.warning_rounded;
    if (alert.severity == 'WARNING') return Icons.warning_amber_rounded;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: _color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: _color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _color,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat("dd/MM/yyyy 'às' HH:mm")
                        .format(alert.triggeredAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!alert.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
