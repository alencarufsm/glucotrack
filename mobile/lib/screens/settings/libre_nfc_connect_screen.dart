import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/libre_ble_provider.dart';
import '../../services/libre_nfc_service.dart';

enum _Step { nfcTap, bleConnect, done, error }

class LibreNfcConnectScreen extends StatefulWidget {
  const LibreNfcConnectScreen({super.key});

  @override
  State<LibreNfcConnectScreen> createState() => _LibreNfcConnectScreenState();
}

class _LibreNfcConnectScreenState extends State<LibreNfcConnectScreen> {
  final _nfc = LibreNfcService();

  _Step _step = _Step.nfcTap;
  String? _error;
  LibreNfcData? _nfcData;
  bool _nfcAvailable = true;

  @override
  void initState() {
    super.initState();
    _checkNfcAndStart();
  }

  @override
  void dispose() {
    _nfc.stopSession();
    super.dispose();
  }

  // ── NFC phase ─────────────────────────────────────────────

  Future<void> _checkNfcAndStart() async {
    final available = await LibreNfcService.isAvailable();
    if (!mounted) return;

    if (!available) {
      setState(() {
        _nfcAvailable = false;
        _step = _Step.error;
        _error =
            'NFC não disponível neste dispositivo ou está desativado nas configurações.';
      });
      return;
    }

    _startNfcSession();
  }

  Future<void> _startNfcSession() async {
    setState(() {
      _step = _Step.nfcTap;
      _error = null;
    });

    try {
      final data = await _nfc.readSensor(
        alertMessage: 'Encoste o celular no sensor FreeStyle Libre',
      );
      if (!mounted) return;

      setState(() {
        _nfcData = data;
        _step = _Step.bleConnect;
      });

      await _connectBle(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── BLE phase ──────────────────────────────────────────────

  Future<void> _connectBle(LibreNfcData nfcData) async {
    final provider = context.read<LibreBleProvider>();

    try {
      await provider.startScanAndConnectWithUid(nfcData);
      if (!mounted) return;

      if (provider.isConnected) {
        setState(() => _step = _Step.done);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.pop();
      } else {
        setState(() {
          _step = _Step.error;
          _error = provider.error ?? 'Não foi possível conectar via Bluetooth.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar sensor'),
        // Impede voltar durante a sessão NFC ativa
        automaticallyImplyLeading: _step != _Step.nfcTap,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_step) {
          _Step.nfcTap => _NfcTapView(key: const ValueKey('nfc')),
          _Step.bleConnect =>
            _ConnectingView(key: const ValueKey('ble'), nfcData: _nfcData!),
          _Step.done => _DoneView(key: const ValueKey('done')),
          _Step.error => _ErrorView(
              key: const ValueKey('error'),
              message: _error ?? 'Erro desconhecido.',
              nfcAvailable: _nfcAvailable,
              onRetry: _startNfcSession,
            ),
        },
      ),
    );
  }
}

// ── Step views ─────────────────────────────────────────────────

class _NfcTapView extends StatefulWidget {
  const _NfcTapView({super.key});

  @override
  State<_NfcTapView> createState() => _NfcTapViewState();
}

class _NfcTapViewState extends State<_NfcTapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone pulsante de NFC
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: 0.85 + (_pulse.value * 0.2),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.nfc,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            'Encoste o celular no sensor',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            'Aproxime a parte de trás do celular diretamente sobre o sensor '
            'FreeStyle Libre 2 Plus (a tag redonda no braço).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          Card(
            elevation: 0,
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O sensor precisa estar ativo. '
                      'Mantenha o celular encostado por 2–3 segundos.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectingView extends StatelessWidget {
  final LibreNfcData nfcData;
  const _ConnectingView({super.key, required this.nfcData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 32),
          Text('Sensor identificado!',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Conectando via Bluetooth…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'UID: ${nfcData.serialHint}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade100,
            ),
            child: Icon(Icons.check_circle_outline,
                size: 60, color: Colors.green.shade700),
          ),
          const SizedBox(height: 32),
          Text('Conectado!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'O sensor FreeStyle Libre está transmitindo glicose via Bluetooth.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final bool nfcAvailable;
  final VoidCallback onRetry;

  const _ErrorView({
    super.key,
    required this.message,
    required this.nfcAvailable,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            nfcAvailable ? Icons.bluetooth_disabled : Icons.nfc_outlined,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            'Não foi possível conectar',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (nfcAvailable)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
        ],
      ),
    );
  }
}
