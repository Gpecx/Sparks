import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../../constants/fs.dart';
import '../admin_controller.dart';
import 'admin_entity_form.dart';

class AdminDialogs {
  static Future<void> showCreateCategory(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminEntityForm(
        title: 'Nova Categoria',
        fields: const [
          FieldConfig(key: FS.title, label: 'Título', required: true),
          FieldConfig(key: 'description', label: 'Descrição', maxLines: 3),
          FieldConfig(key: 'icon', label: 'Emoji ou Ícone (Ex: 🚀)', hint: 'Escolha um símbolo marcante', required: false),
          FieldConfig(key: 'imageUrl', label: 'URL da Imagem de Capa', hint: 'https://exemplo.com/imagem.png', required: false),
        ],
        onSave: (data) async {
          final id = await ref.read(adminControllerProvider.notifier).create(AdminEntity.categories, data);
          return id ?? '';
        },
      ),
    );
  }

  static Future<void> showEditCategory(BuildContext context, WidgetRef ref, String catId, Map<String, dynamic> data) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminEntityForm(
        title: 'Editar Categoria',
        initialValues: data.map((k, v) => MapEntry(k, v.toString())),
        fields: const [
          FieldConfig(key: FS.title, label: 'Título', required: true),
          FieldConfig(key: 'description', label: 'Descrição', maxLines: 3),
          FieldConfig(key: 'icon', label: 'Emoji ou Ícone', required: false),
          FieldConfig(key: 'imageUrl', label: 'URL da Imagem', required: false),
        ],
        onSave: (newData) async {
          await ref.read(adminControllerProvider.notifier).update(AdminEntity.categories, catId, newData);
          return 'ok';
        },
      ),
    );
  }

  static Future<void> showCreateModule(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminEntityForm(
        title: 'Novo Módulo',
        fields: const [
          FieldConfig(key: FS.title, label: 'Título do Módulo', required: true),
          FieldConfig(key: 'subtitle', label: 'Subtítulo/Descrição'),
          FieldConfig(key: 'icon', label: 'Ícone (Ex: 📘)', required: false),
          FieldConfig(key: 'imageUrl', label: 'URL da Imagem', required: false),
        ],
        onSave: (data) async {
          final id = await ref.read(adminControllerProvider.notifier).create(AdminEntity.modules, data);
          return id ?? '';
        },
      ),
    );
  }

  static Future<void> showEditModule(BuildContext context, WidgetRef ref, String modId, Map<String, dynamic> data) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminEntityForm(
        title: 'Editar Módulo',
        initialValues: data.map((k, v) => MapEntry(k, v.toString())),
        fields: const [
          FieldConfig(key: FS.title, label: 'Título do Módulo', required: true),
          FieldConfig(key: 'subtitle', label: 'Subtítulo/Descrição'),
          FieldConfig(key: 'icon', label: 'Ícone', required: false),
          FieldConfig(key: 'imageUrl', label: 'URL da Imagem', required: false),
        ],
        onSave: (newData) async {
          await ref.read(adminControllerProvider.notifier).update(AdminEntity.modules, modId, newData);
          return 'ok';
        },
      ),
    );
  }

  static Future<void> showTrailWizard(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _TrailWizardDialog(ref: ref),
    );
  }

  static Future<void> showImportJSON(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ImportJSONDialog(ref: ref),
    );
  }

  static Future<void> showConfirmDelete({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(content, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('DELETAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ImportJSONDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ImportJSONDialog({required this.ref});

  @override
  State<_ImportJSONDialog> createState() => _ImportJSONDialogState();
}

class _ImportJSONDialogState extends State<_ImportJSONDialog> {
  final _jsonCtrl = TextEditingController();
  bool _isSaving = false;
  bool _showSuccess = false;
  String? _error;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _jsonCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Cole o conteúdo JSON primeiro.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> data = jsonDecode(text);
      
      final success = await widget.ref.read(adminControllerProvider.notifier).importFromJSON(data);

      if (success && mounted) {
        setState(() {
          _isSaving = false;
          _showSuccess = true;
        });
      } else {
        if (mounted) {
          final state = widget.ref.read(adminControllerProvider);
          setState(() {
            _isSaving = false;
            _error = state.errorMessage ?? 'Ocorreu um erro desconhecido.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'JSON Inválido: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? size.width * 0.2 : 20,
        vertical: 24,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _showSuccess ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Importar via JSON',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Cole o código JSON para criar a estrutura completa',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CONTEÚDO JSON',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _jsonCtrl,
                    maxLines: 12,
                    style: const TextStyle(
                      color: AppColors.textPrimary, 
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: '{\n  "category": "...",\n  "module": "...",\n  "trail": "...",\n  "questions": [...]\n}',
                      fillColor: Colors.black26,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _submit,
                          icon: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload_file_rounded),
                          label: Text(_isSaving ? 'IMPORTANDO...' : 'IMPORTAR AGORA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 32),
          const Text(
            'Importação Concluída!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'O conteúdo JSON foi processado e a estrutura educacional foi criada com sucesso.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showSuccess = false;
                      _jsonCtrl.clear();
                      _error = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('IMPORTAR OUTRO', style: TextStyle(color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('FECHAR'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _TrailWizardDialog extends StatefulWidget {
  final WidgetRef ref;
  const _TrailWizardDialog({required this.ref});

  @override
  State<_TrailWizardDialog> createState() => _TrailWizardDialogState();
}

class _TrailWizardDialogState extends State<_TrailWizardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _lessonsCtrl = TextEditingController(text: '4');
  final _quizzesCtrl = TextEditingController(text: '1');
  final _questionsCtrl = TextEditingController(text: '5');
  
  bool _isSaving = false;
  bool _showSuccess = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _lessonsCtrl.dispose();
    _quizzesCtrl.dispose();
    _questionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final success = await widget.ref.read(adminControllerProvider.notifier).generateTrail(
        title: _titleCtrl.text,
        numLessons: int.tryParse(_lessonsCtrl.text) ?? 0,
        numEvaluations: int.tryParse(_quizzesCtrl.text) ?? 0,
        questionsPerLesson: 0,
        questionsPerEvaluation: int.tryParse(_questionsCtrl.text) ?? 0,
      );

      if (success && mounted) {
        setState(() {
          _isSaving = false;
          _showSuccess = true;
        });
      } else {
        if (mounted) setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            fillColor: AppColors.card.withValues(alpha: 0.5),
            hintText: 'Digite aqui...',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? size.width * 0.2 : 20,
        vertical: 24,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _showSuccess ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.orange.withValues(alpha: 0.15), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.orange, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gerar Estrutura de Trilha',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Isso criará lições e avaliações automaticamente',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField('Título da Trilha', _titleCtrl),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Qtd. Lições', _lessonsCtrl, isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Qtd. Provas', _quizzesCtrl, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField('Questões por Prova', _questionsCtrl, isNumber: true),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (!_isSaving)
                          Expanded(
                            flex: 1,
                            child: TextButton(
                              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                              child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),
                            ),
                          ),
                        if (!_isSaving) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                elevation: 8,
                                shadowColor: AppColors.orange.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.auto_awesome, size: 20),
                                        SizedBox(width: 12),
                                        Text('GERAR TRILHA'),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.orange, AppColors.orange.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 32),
          const Text(
            'Trilha Gerada com Sucesso!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A estrutura de lições e questões foi criada e já está disponível.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('FECHAR'),
            ),
          ),
        ],
      ),
    );
  }
}
