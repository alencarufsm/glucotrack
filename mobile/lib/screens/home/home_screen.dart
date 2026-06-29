import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/libre_ble_provider.dart';
import '../../providers/librelink_provider.dart';
import '../../providers/readings_provider.dart';
import '../../widgets/glucose_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReadingsProvider>().loadLatestReading();
      context.read<ReadingsProvider>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final readings = context.watch<ReadingsProvider>();
    final libre = context.watch<LibreLinkProvider>();
    final libreBle = context.watch<LibreBleProvider>();
    final theme = Theme.of(context);
    final latest = readings.latestReading;

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${auth.profile?.name.split(' ').first ?? 'usuário'} 👋'),
        actions: [
          // Badge de alertas não lidos
          if (readings.unreadAlertCount > 0)
            IconButton(
              icon: Badge(
                label: Text('${readings.unreadAlertCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => context.push('/alerts'),
            )
          else
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/alerts'),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await readings.loadLatestReading();
          await readings.loadAlerts();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card da última medição
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('Última medição',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      const SizedBox(height: 16),
                      if (latest != null) ...[
                        GlucoseIndicator(
                          value: latest.value,
                          status: latest.status,
                          large: true,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          latest.mealContextLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat("dd/MM/yyyy 'às' HH:mm").format(latest.measuredAt.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.monitor_heart_outlined, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhuma medição registrada ainda',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botão principal — registrar nova medição
              FilledButton.icon(
                onPressed: () => context.push('/readings/new'),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Registrar nova medição'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 12),

              // Ações secundárias
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/history'),
                      icon: const Icon(Icons.show_chart),
                      label: const Text('Histórico'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/alerts'),
                      icon: const Icon(Icons.notifications_outlined),
                      label: const Text('Alertas'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Card BLE direto (FreeStyle Libre 2 Plus via Bluetooth)
              _LibreBleCard(ble: libreBle),

              const SizedBox(height: 8),

              // Card LibreLink Up (nuvem Abbott)
              _LibreCard(
                libre: libre,
                onSync: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final errorColor = theme.colorScheme.error;
                  try {
                    final count = await libre.sync();
                    await readings.loadLatestReading();
                    messenger.showSnackBar(SnackBar(
                      content: Text(count > 0
                          ? '$count leituras sincronizadas do FreeStyle Libre'
                          : 'Nenhuma leitura nova encontrada'),
                    ));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(
                      content: Text('Erro ao sincronizar: ${libre.error ?? e}'),
                      backgroundColor: errorColor,
                    ));
                  }
                },
              ),

              const SizedBox(height: 24),

              // Faixas de referência — ajuda o usuário a interpretar os valores
              _ReferenceRangeCard(
                targetMin: auth.profile?.targetMin ?? 70,
                targetMax: auth.profile?.targetMax ?? 180,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibreBleCard extends StatelessWidget {
  final LibreBleProvider ble;
  const _LibreBleCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Não configurado — mostra botão de configuração
    if (!ble.isConfigured) {
      return OutlinedButton.icon(
        onPressed: () => context.push('/settings/libre-ble'),
        icon: const Icon(Icons.bluetooth),
        label: const Text('Conectar sensor (NFC + Bluetooth)'),
      );
    }

    final state = ble.state;
    final reading = ble.lastReading;
    final isConnected = ble.isConnected;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (state) {
      case LibreBleConnectionState.connected:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.bluetooth_connected;
        statusLabel = 'Conectado';
      case LibreBleConnectionState.connecting ||
            LibreBleConnectionState.authenticating:
        statusColor = theme.colorScheme.tertiary;
        statusIcon = Icons.bluetooth_searching;
        statusLabel = state == LibreBleConnectionState.authenticating
            ? 'Autenticando...'
            : 'Conectando...';
      case LibreBleConnectionState.disconnected:
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusIcon = Icons.bluetooth_disabled;
        statusLabel = 'Desconectado';
      default:
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusIcon = Icons.bluetooth;
        statusLabel = 'BLE';
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Bluetooth direto · $statusLabel',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: statusColor),
                ),
                const Spacer(),
                if (!isConnected)
                  TextButton.icon(
                    onPressed: () => context.push('/settings/libre-ble'),
                    icon: const Icon(Icons.bluetooth_searching, size: 16),
                    label: const Text('Reconectar'),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                if (isConnected)
                  IconButton(
                    icon: const Icon(Icons.bluetooth_disabled, size: 20),
                    tooltip: 'Desconectar',
                    onPressed: () => ble.disconnect(),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (reading != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Text(
                    '${reading.valueInMgDl}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('mg/dL',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(width: 8),
                  Text(
                    ble.trendArrow(reading.trendPerMinute),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              Text(
                'Agora · sensor ao vivo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LibreCard extends StatelessWidget {
  final LibreLinkProvider libre;
  final VoidCallback onSync;

  const _LibreCard({required this.libre, required this.onSync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!libre.isConfigured) {
      return OutlinedButton.icon(
        onPressed: () => context.push('/settings/libre'),
        icon: const Icon(Icons.sensors),
        label: const Text('Conectar FreeStyle Libre 2 Plus'),
      );
    }

    final lastSyncText = libre.lastSync != null
        ? 'Última sync: ${DateFormat("dd/MM HH:mm").format(libre.lastSync!.toLocal())}'
        : 'Nunca sincronizado';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.sensors, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libre.patientName ?? 'FreeStyle Libre',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(lastSyncText,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (libre.isSyncing)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Sincronizar agora',
                onPressed: onSync,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceRangeCard extends StatelessWidget {
  final int targetMin;
  final int targetMax;

  const _ReferenceRangeCard({required this.targetMin, required this.targetMax});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Faixas de referência',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _RangeRow(color: Colors.red.shade600,    label: 'Hipoglicemia',       range: '< 70 mg/dL'),
            _RangeRow(color: Colors.green.shade600,  label: 'Meta pessoal',        range: '$targetMin–$targetMax mg/dL'),
            _RangeRow(color: Colors.orange.shade700, label: 'Hiperglicemia',       range: '181–249 mg/dL'),
            _RangeRow(color: Colors.red.shade700,    label: 'Hiperglicemia severa', range: '≥ 250 mg/dL'),
          ],
        ),
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  final Color color;
  final String label;
  final String range;

  const _RangeRow({required this.color, required this.label, required this.range});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(range,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
