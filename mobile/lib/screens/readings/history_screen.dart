import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/glucose_reading.dart';
import '../../providers/readings_provider.dart';
import '../../widgets/glucose_indicator.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final from = DateTime.now().subtract(Duration(days: _selectedDays));
    context.read<ReadingsProvider>().loadReadings(from: from);
  }

  @override
  Widget build(BuildContext context) {
    final readings = context.watch<ReadingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          // Filtro de período
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7d')),
              ButtonSegment(value: 30, label: Text('30d')),
            ],
            selected: {_selectedDays},
            onSelectionChanged: (s) {
              setState(() => _selectedDays = s.first);
              _load();
            },
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: readings.loading
          ? const Center(child: CircularProgressIndicator())
          : readings.readings.isEmpty
              ? _EmptyState()
              : _ReadingsContent(readings: readings.readings, theme: theme),
    );
  }
}

class _ReadingsContent extends StatelessWidget {
  final List<GlucoseReading> readings;
  final ThemeData theme;

  const _ReadingsContent({required this.readings, required this.theme});

  @override
  Widget build(BuildContext context) {
    // Estatísticas do período
    final values = readings.map((r) => r.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final inRange = values.where((v) => v >= 70 && v <= 180).length;
    final tir = (inRange / values.length * 100).round();

    return Column(
      children: [
        // Métricas resumidas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricChip(label: 'Média', value: '${avg.round()}', unit: 'mg/dL'),
              _MetricChip(label: 'Mínimo', value: '$min', unit: 'mg/dL'),
              _MetricChip(label: 'Máximo', value: '$max', unit: 'mg/dL'),
              _MetricChip(label: 'TIR', value: '$tir', unit: '%',
                  color: tir >= 70 ? Colors.green.shade700 : Colors.orange.shade700),
            ],
          ),
        ),

        // Gráfico de linha
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 220,
            child: _GlucoseChart(readings: readings),
          ),
        ),

        // Lista de medições
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: readings.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _ReadingTile(reading: readings[i]),
          ),
        ),
      ],
    );
  }
}

class _GlucoseChart extends StatelessWidget {
  final List<GlucoseReading> readings;

  const _GlucoseChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    // Inverte para mostrar do mais antigo ao mais recente no gráfico
    final sorted = readings.reversed.toList();
    final spots = sorted.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.value.toDouble())).toList();

    return LineChart(
      LineChartData(
        minY: 40,
        maxY: 300,
        gridData: FlGridData(
          drawHorizontalLine: true,
          horizontalInterval: 70,
          getDrawingHorizontalLine: (v) => FlLine(
            color: v == 70 || v == 180
                ? Colors.red.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
            strokeWidth: v == 70 || v == 180 ? 1.5 : 0.8,
            dashArray: v == 70 || v == 180 ? [5, 3] : null,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 70,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              getDotPainter: (spot, _, __, ___) {
                final v = spot.y.toInt();
                Color c = v < 70 || v > 180
                    ? Colors.red.shade600
                    : Colors.green.shade600;
                return FlDotCirclePainter(radius: 3, color: c, strokeWidth: 0);
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final GlucoseReading reading;

  const _ReadingTile({required this.reading});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: GlucoseIndicator(value: reading.value, status: reading.status),
      title: Text(reading.mealContextLabel,
          style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        DateFormat("dd/MM 'às' HH:mm").format(reading.measuredAt.toLocal()),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: reading.notes != null
          ? Icon(Icons.notes, size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? color;

  const _MetricChip({required this.label, required this.value,
      required this.unit, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text.rich(TextSpan(children: [
          TextSpan(text: value,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: color ?? Theme.of(context).colorScheme.onSurface)),
          TextSpan(text: ' $unit',
              style: Theme.of(context).textTheme.labelSmall),
        ])),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.show_chart, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Nenhuma medição no período',
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
