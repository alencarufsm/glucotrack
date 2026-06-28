import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/librelink_provider.dart';
import '../../services/librelink_service.dart';

class LibreLinkSetupScreen extends StatefulWidget {
  const LibreLinkSetupScreen({super.key});

  @override
  State<LibreLinkSetupScreen> createState() => _LibreLinkSetupScreenState();
}

class _LibreLinkSetupScreenState extends State<LibreLinkSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isTesting = false;
  String? _errorMessage;

  // Resultado do teste de credenciais — aguardando seleção de paciente
  List<LibreConnection> _connections = [];
  LibreConnection? _selectedConnection;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _testCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isTesting = true;
      _errorMessage = null;
      _connections = [];
      _selectedConnection = null;
    });

    try {
      final provider = context.read<LibreLinkProvider>();
      final result = await provider.testCredentials(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (result.connections.isEmpty) {
        setState(() => _errorMessage =
            'Nenhum paciente vinculado encontrado. Verifique se o LibreLink Up está ativado na conta do paciente.');
        return;
      }

      setState(() {
        _connections = result.connections;
        _selectedConnection =
            result.connections.length == 1 ? result.connections.first : null;
      });
    } catch (e) {
      setState(() => _errorMessage =
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    final conn = _selectedConnection;
    if (conn == null) return;

    try {
      await context.read<LibreLinkProvider>().configure(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            patientId: conn.patientId,
            patientName: conn.displayName,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = _connections.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Conectar FreeStyle Libre')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Explicação
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Use o e-mail e senha da conta LibreLink do paciente. '
                          'Os dados são buscados da nuvem Abbott — o sensor continua '
                          'funcionando normalmente.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _emailCtrl,
                enabled: !connected,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'E-mail LibreLink',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordCtrl,
                enabled: !connected,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Senha LibreLink',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Informe a senha' : null,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],

              const SizedBox(height: 24),

              if (!connected)
                FilledButton(
                  onPressed: _isTesting ? null : _testCredentials,
                  child: _isTesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verificar credenciais'),
                ),

              // Lista de pacientes vinculados
              if (connected) ...[
                Text('Paciente monitorado',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ..._connections.map(
                  (c) => RadioListTile<LibreConnection>(
                    title: Text(c.displayName.isEmpty ? 'Paciente' : c.displayName),
                    value: c,
                    groupValue: _selectedConnection,
                    onChanged: (v) => setState(() => _selectedConnection = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _selectedConnection == null ? null : _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Salvar configuração'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _connections = [];
                    _selectedConnection = null;
                  }),
                  child: const Text('Usar outras credenciais'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
