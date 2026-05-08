import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ADMIN ENTITY FORM — Widget de formulário reutilizável
//  Recebe campos dinâmicos e retorna Map<String, String> no onSave.
// ─────────────────────────────────────────────────────────────────

class FieldConfig {
  final String key;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;

  const FieldConfig({
    required this.key,
    required this.label,
    this.hint = '',
    this.required = true,
    this.maxLines = 1,
    this.keyboardType,
  });
}

class AdminEntityForm extends StatefulWidget {
  final String title;
  final List<FieldConfig> fields;
  final Map<String, String> initialValues;
  final bool isSaving;
  final void Function(Map<String, String> data) onSave;

  const AdminEntityForm({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.initialValues = const {},
    this.isSaving = false,
  });

  @override
  State<AdminEntityForm> createState() => _AdminEntityFormState();
}

class _AdminEntityFormState extends State<AdminEntityForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in widget.fields)
        f.key: TextEditingController(text: widget.initialValues[f.key] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final data = {for (final f in widget.fields) f.key: _controllers[f.key]!.text.trim()};
    widget.onSave(data);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ───────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Fields ───────────────────────────────────────
                ...widget.fields.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
	                        controller: _controllers[f.key],
	                        maxLines: f.maxLines,
	                        keyboardType: f.keyboardType,
	                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: f.label,
                          hintText: f.hint,
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                        ),
                        validator: f.required
                            ? (v) => (v == null || v.trim().isEmpty) ? '${f.label} é obrigatório' : null
                            : null,
                      ),
                    )),
                const SizedBox(height: 8),
                // ── Save Button ──────────────────────────────────
                ElevatedButton(
                  onPressed: widget.isSaving ? null : _submit,
                  child: widget.isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('SALVAR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
