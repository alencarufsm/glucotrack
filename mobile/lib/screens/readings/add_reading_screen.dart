import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/glucose_reading.dart';
import '../../providers/auth_provider.dart';
import '../../providers/readings_provider.dart';
import '../../widgets/glucose_indicator.dart';

class AddReadingScreen extends StatefulWidget {
  const AddReadingScreen({super.key});

  @override
  State<AddReadingScreen> createState() => _AddReadingScreenState();
}

class _AddReadingScreenState extends State<AddReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _mealContext = 'OTHER';
  GlucoseStatus? _previewStatus;

  static const _mealOptions = [
    ('FASTING', 'Jejum'),
    ('PRE_MEAL', 'Pré-refeição'),
    ('POST_MEAL', 'Pós-refeição'),
    ('BEDTIME', 'Antes de dormir'),
    ('OTHER', 'Outro momento'),
  ];

  void _updatePreview(String text) {
    final value = int.tryParse(text);
    if (value == null) {
      setState(() => _previewStatus = null);
      return;
    }
    GlucoseStatus status;
    if (value < 54)        status = GlucoseStatus.emergency;
    else if (value < 70)   status = GlucoseStatus.low;
    else if (value <= 180) status = GlucoseStatus.normal;
    else if (value <= 249) status = GlucoseStatus.high;
    else                   status = GlucoseStatus.veryHigh;
    setState(() => _previewStatus = status);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final readings = context.read<ReadingsProvider>();
    final result = await readings.addReading(
      value: int.parse(_valueCtrl.text),
      mealContext: _mealContext,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medição de ${result.value} mg/dL registrada!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(readings.error ?? 'Erro ao registrar'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final readings = context.watch<ReadingsProvider>();
    final theme = Theme.of(context);
    final isType1 = auth.profile?.isType1 ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Nova medição')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Campo de valor com preview em tempo real
              TextFormField(
                controller: _valueCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Glicemia (mg/dL)',
                  hintText: 'Ex: 120',
                  suffixText: 'mg/dL',
                ),
                onChanged: _updatePreview,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Digite o valor';
                  final n = int.tryParse(v);
                  if (n == null || n < 20 || n > 600) return 'Valor entre 20 e 600';
                  return null;
                },
              ),

              // Preview visual do nível de glicemia
              if (_previewStatus != null) ...[
                const SizedBox(height: 20),
                Center(
                  child: GlucoseIndicator(
                    value: int.tryParse(_valueCtrl.text) ?? 0,
                    status: _previewStatus!,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Momento em relação à refeição
              Text('Momento da medição', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _mealOptions.map((opt) {
                  final selected = _mealContext == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _mealContext = opt.$1),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Observações
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  hintText: 'Ex: senti tontura, comi macarrão...',
                  alignLabelWithHint: true,
                ),
              ),

              // Lembrete de insulina para Tipo 1
              if (isType1) ...[
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.vaccines_outlined,
                            color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lembre-se de registrar a dose de insulina se aplicou alguma.',
                            style: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: readings.loading ? null : _submit,
                icon: readings.loading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: const Text('Salvar medição'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
