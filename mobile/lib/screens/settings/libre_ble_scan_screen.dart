import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../providers/libre_ble_provider.dart';

class LibreBleScanScreen extends StatefulWidget {
  const LibreBleScanScreen({super.key});

  @override
  State<LibreBleScanScreen> createState() => _LibreBleScanScreenState();
}

class _LibreBleScanScreenState extends State<LibreBleScanScreen> {
  final _serialCtrl = TextEditingController();
  bool _permissionsGranted = false;
  bool _checkingPermissions = true;
  LibreSensorDevice? _connecting;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _serialCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final granted = await _requestBlePermissions();
    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
        _checkingPermissions = false;
      });
    }
  }

  Future<bool> _requestBlePermissions() async {
    if (Platform.isIOS) {
      // iOS: única permissão BLE — mapeada para NSBluetoothAlwaysUsageDescription
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }

    // Android 12+: BLUETOOTH_SCAN + BLUETOOTH_CONNECT
    // Android < 12: BLUETOOTH + ACCESS_FINE_LOCATION
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<void> _startScan() async {
    final provider = context.read<LibreBleProvider>();
    try {
      await provider.startScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao escanear: $e')),
        );
      }
    }
  }

  Future<void> _connectTo(LibreSensorDevice sensor) async {
    // Pré-preenche o serial a partir do nome BLE ("ABBOTT3MH01M9M1XW" → "3MH01M9M1XW")
    // se o usuário não digitou manualmente
    final typed = _serialCtrl.text.trim();
    final serial = typed.isNotEmpty
        ? typed
        : (sensor.serialHint ?? '');

    setState(() => _connecting = sensor);

    final provider = context.read<LibreBleProvider>();
    await provider.stopScan();
    await provider.connect(sensor, serial: serial.isNotEmpty ? serial : null);

    if (!mounted) return;
    setState(() => _connecting = null);

    if (provider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sensor conectado com sucesso!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar via Bluetooth')),
      body: _checkingPermissions
          ? const Center(child: CircularProgressIndicator())
          : !_permissionsGranted
              ? _PermissionDeniedView(onRetry: _checkPermissions)
              : _ScanView(
                  serialCtrl: _serialCtrl,
                  connecting: _connecting,
                  onScan: _startScan,
                  onConnect: _connectTo,
                ),
    );
  }
}

// ── Views ──────────────────────────────────────────────────

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionDeniedView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled,
              size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 24),
          Text(
            'Permissão Bluetooth necessária',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'O GlicoTrack precisa de acesso ao Bluetooth para ler '
            'o sensor FreeStyle Libre diretamente.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await openAppSettings();
              onRetry();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Abrir configurações'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _ScanView extends StatelessWidget {
  final TextEditingController serialCtrl;
  final LibreSensorDevice? connecting;
  final VoidCallback onScan;
  final void Function(LibreSensorDevice) onConnect;

  const _ScanView({
    required this.serialCtrl,
    required this.connecting,
    required this.onScan,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibreBleProvider>();
    final theme = Theme.of(context);
    final state = provider.state;
    final isScanning = state == LibreBleConnectionState.scanning;
    final sensors = provider.foundSensors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Aviso de exclusividade
          Card(
            elevation: 0,
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: theme.colorScheme.onTertiaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O sensor se conecta a UM app por vez. '
                      'Para usar o GlicoTrack diretamente via Bluetooth, '
                      'feche o aplicativo LibreLink neste celular.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Campo do serial — detectado automaticamente do nome BLE ou digitado manualmente
          TextFormField(
            controller: serialCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Número de série do sensor',
              hintText: 'Ex.: 3MH01M9M1XW',
              prefixIcon: Icon(Icons.qr_code),
              helperText:
                  'Detectado automaticamente ao encontrar o sensor. '
                  'Também impresso na embalagem após "(21)".',
              helperMaxLines: 2,
            ),
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: isScanning ? null : onScan,
            icon: isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bluetooth_searching),
            label: Text(isScanning ? 'Escaneando...' : 'Buscar sensor'),
          ),

          const SizedBox(height: 24),

          if (isScanning && sensors.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Aproxime o celular do sensor\nFreeStyle Libre 2 Plus',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          if (sensors.isNotEmpty) ...[
            Text('Sensores encontrados',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...sensors.map(
              (entry) => _SensorTile(
                entry: entry,
                isConnecting: connecting?.id == entry.sensor.id,
                onTap: () {
                  // Preenche serial automaticamente se ainda não foi digitado
                  final hint = entry.sensor.serialHint;
                  if (serialCtrl.text.isEmpty && hint != null) {
                    serialCtrl.text = hint;
                  }
                  onConnect(entry.sensor);
                },
              ),
            ),
          ],

          if (!isScanning && sensors.isEmpty && state != LibreBleConnectionState.idle)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum sensor encontrado.\n'
                  'Certifique-se de que o sensor está ativo\n'
                  'e próximo ao celular.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (provider.error != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  provider.error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  final ({LibreSensorDevice sensor, int rssi}) entry;
  final bool isConnecting;
  final VoidCallback onTap;

  const _SensorTile({
    required this.entry,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sensor = entry.sensor;
    final rssi = entry.rssi;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.sensors, color: theme.colorScheme.primary),
        title: Text(sensor.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sensor.serialHint != null)
              Text('Serial: ...${sensor.serialHint}'),
            Text('Sinal: ${_rssiLabel(rssi)} ($rssi dBm)',
                style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton(
                onPressed: onTap,
                child: const Text('Conectar'),
              ),
        isThreeLine: sensor.serialHint != null,
      ),
    );
  }

  String _rssiLabel(int rssi) {
    if (rssi >= -60) return 'Excelente';
    if (rssi >= -75) return 'Bom';
    if (rssi >= -90) return 'Fraco';
    return 'Muito fraco';
  }
}
