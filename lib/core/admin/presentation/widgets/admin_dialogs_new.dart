import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../../constants/fs.dart';
import '../admin_controller.dart';
import 'admin_entity_form.dart';

class AdminDialogs {
  static Future<void> showCreateCategory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminEntityForm(
        title: 'Nova Categoria',
        fields: const [
          FieldConfig(key: FS.title, label: 'Título', required: true),
          FieldConfig(key: 'description', label: 'Descrição', maxLines: 3),
          FieldConfig(
            key: 'icon',
            label: 'Emoji ou Ícone (Ex: 🚀)',
            hint: 'Escolha um símbolo marcante',
            required: false,
          ),
          FieldConfig(
            key: 'imageUrl',
            label: 'URL da Imagem de Capa',
            hint: 'https://exemplo.com/imagem.png',
            required: false,
          ),
        ],
        onSave: (data) async {
          final id = await ref
              .read(adminControllerProvider.notifier)
              .create(AdminEntity.categories, data);
          return id ?? '';
        },
      ),
    );
  }

  static Future<void> showEditCategory(
    BuildContext context,
    WidgetRef ref,
    String catId,
    Map<String, dynamic> data,
  ) async {
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
          await ref
              .read(adminControllerProvider.notifier)
              .update(AdminEntity.categories, catId, newData);
          return 'ok';
        },
      ),
    );
  }

  static Future<void> showCreateModule(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
          final id = await ref
              .read(adminControllerProvider.notifier)
              .create(AdminEntity.modules, data);
          return id ?? '';
        },
      ),
    );
  }

  static Future<void> showEditModule(
    BuildContext context,
    WidgetRef ref,
    String modId,
    Map<String, dynamic> data,
  ) async {
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
          await ref
              .read(adminControllerProvider.notifier)
              .update(AdminEntity.modules, modId, newData);
          return 'ok';
        },
      ),
    );
  }

  static Future<void> showTrailWizard(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
      builder: (ctx) => _JSONImportDialog(ref: ref),
    );
  }

  static Future<void> showBulkImportJSON(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BulkJSONImportDialog(ref: ref),
    );
  }

  static Future<void> showImportEbook(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _EbookImportDialog(ref: ref),
    );
  }

  static Future<void> showDeleteAllContent(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeleteAllContentDialog(ref: ref),
    );
  }

  static Future<void> showConfirmDelete({
    required BuildContext context,
    required String title,
    required String content,
    required Future<void> Function() onConfirm,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ConfirmDeleteDialog(
        title: title,
        content: content,
        onConfirm: onConfirm,
      ),
    );
  }
}

// ─── CONFIRM DELETE DIALOG (com loading) ─────────────────────────────────────
class _ConfirmDeleteDialog extends StatefulWidget {
  final String title;
  final String content;
  final Future<void> Function() onConfirm;

  const _ConfirmDeleteDialog({
    required this.title,
    required this.content,
    required this.onConfirm,
  });

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surface, width: 1),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Text(
        widget.content,
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.only(right: 24, bottom: 24),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _isDeleting ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Text('DELETAR', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _JSONImportDialog extends StatefulWidget {

  final WidgetRef ref;
  const _JSONImportDialog({required this.ref});

  @override
  State<_JSONImportDialog> createState() => _JSONImportDialogState();
}

class _JSONImportDialogState extends State<_JSONImportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _jsonCtrl = TextEditingController();

  bool _isSaving = false;
  String? _errorMsg;
  String? _loadedFileName;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      setState(() => _errorMsg = 'Não foi possível ler o arquivo.');
      return;
    }
    try {
      final raw = utf8.decode(bytes);
      jsonDecode(raw);
      setState(() {
        _jsonCtrl.text = raw;
        _loadedFileName = result.files.first.name;
        _errorMsg = null;
      });
    } catch (e) {
      setState(() => _errorMsg = 'Arquivo JSON inválido: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(_jsonCtrl.text);
      final success = await widget.ref
          .read(adminControllerProvider.notifier)
          .importFromJSON(jsonMap);

      if (success && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context, rootNavigator: true).pop();
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('JSON importado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        widget.ref.read(adminControllerProvider.notifier).applyPendingNavigation();
      } else {
        if (mounted) {
          final err = widget.ref.read(adminControllerProvider).errorMessage;
          setState(() {
             _isSaving = false;
             _errorMsg = err ?? 'Erro desconhecido ao importar JSON';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _isSaving = false;
           _errorMsg = 'JSON Inválido ou erro: $e';
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
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
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
          child: _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.orange.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
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
                  child: const Icon(
                    Icons.data_object,
                    color: AppColors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Importar via JSON',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Cole o conteúdo JSON com as questões, módulo e categoria',
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
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMsg != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Text(
                _errorMsg!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
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
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _pickFile,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('SELECIONAR ARQUIVO .JSON'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    if (_loadedFileName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Arquivo carregado: $_loadedFileName',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _jsonCtrl,
                      maxLines: 12,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        fillColor: AppColors.card.withValues(alpha: 0.5),
                        hintText: 'Cole o JSON aqui ou clique em SELECIONAR ARQUIVO acima\n\n{\n  "category": "...",\n  "module": "...",\n  "trail": "...",\n  "questions": [...]\n}',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (!_isSaving)
                          Expanded(
                            flex: 1,
                            child: TextButton(
                              onPressed: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(),
                              child: const Text(
                                'CANCELAR',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
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
                                shadowColor: AppColors.orange.withValues(
                                  alpha: 0.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.file_upload, size: 20),
                                        SizedBox(width: 12),
                                        Text('IMPORTAR'),
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
      final success = await widget.ref
          .read(adminControllerProvider.notifier)
          .generateTrail(
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
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
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
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
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.orange.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
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
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.orange,
                    size: 24,
                  ),
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
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
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
                        Expanded(
                          child: _buildTextField(
                            'Qtd. Lições',
                            _lessonsCtrl,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            'Qtd. Provas',
                            _quizzesCtrl,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Questões por Prova',
                      _questionsCtrl,
                      isNumber: true,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (!_isSaving)
                          Expanded(
                            flex: 1,
                            child: TextButton(
                              onPressed: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(),
                              child: const Text(
                                'CANCELAR',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
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
                                shadowColor: AppColors.orange.withValues(
                                  alpha: 0.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                colors: [
                  AppColors.orange,
                  AppColors.orange.withValues(alpha: 0.7),
                ],
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
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 48,
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('FECHAR'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BULK JSON IMPORT DIALOG ─────────────────────────────────────────────────
class _BulkJSONImportDialog extends StatefulWidget {
  final WidgetRef ref;
  const _BulkJSONImportDialog({required this.ref});

  @override
  State<_BulkJSONImportDialog> createState() => _BulkJSONImportDialogState();
}

class _BulkJSONImportDialogState extends State<_BulkJSONImportDialog> {
  _Phase _phase = _Phase.idle;
  int _done = 0;
  int _total = 0;
  int _success = 0;
  int _failed = 0;
  String? _errorMsg;

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      setState(() => _errorMsg = 'Não foi possível ler o arquivo.');
      return;
    }

    List<dynamic> jsonList;
    try {
      final raw = utf8.decode(bytes);
      jsonList = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      setState(() => _errorMsg = 'Arquivo inválido: $e');
      return;
    }

    setState(() {
      _phase = _Phase.loading;
      _total = jsonList.length;
      _done = 0;
      _success = 0;
      _failed = 0;
      _errorMsg = null;
    });

    final counts = await widget.ref
        .read(adminControllerProvider.notifier)
        .importBulkFromJSON(
          jsonList,
          onProgress: (done, total) {
            if (mounted) setState(() => _done = done);
          },
        );

    if (mounted) {
      setState(() {
        _phase = _Phase.done;
        _success = counts['success'] ?? 0;
        _failed = counts['failed'] ?? 0;
      });
    }
  }

  Future<void> _pickMultipleAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final List<dynamic> jsonList = [];
    final List<String> parseErrors = [];

    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        parseErrors.add('${file.name}: bytes nulos');
        continue;
      }
      try {
        final raw = utf8.decode(bytes);
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          jsonList.add(parsed);
        } else if (parsed is List) {
          jsonList.addAll(parsed);
        } else {
          parseErrors.add('${file.name}: formato não suportado');
        }
      } catch (e) {
        parseErrors.add('${file.name}: $e');
      }
    }

    if (jsonList.isEmpty) {
      setState(() => _errorMsg =
          'Nenhum arquivo válido. Erros:\n${parseErrors.take(3).join("\n")}');
      return;
    }

    setState(() {
      _phase = _Phase.loading;
      _total = jsonList.length;
      _done = 0;
      _success = 0;
      _failed = 0;
      _errorMsg = null;
    });

    final counts = await widget.ref
        .read(adminControllerProvider.notifier)
        .importBulkFromJSON(
          jsonList,
          onProgress: (done, total) {
            if (mounted) setState(() => _done = done);
          },
        );

    if (mounted) {
      setState(() {
        _phase = _Phase.done;
        _success = counts['success'] ?? 0;
        _failed = (counts['failed'] ?? 0) + parseErrors.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.upload_file, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Importação em Massa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_phase != _Phase.loading)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              if (_phase == _Phase.idle) ...[
                const Text(
                  'Escolha uma das opções:\n• Arquivo único: all_trails.json (array)\n• Múltiplos arquivos: vários .json de uma vez (Ctrl+clique)',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder_copy),
                    label: const Text('SELECIONAR MÚLTIPLOS ARQUIVOS .JSON'),
                    onPressed: _pickMultipleAndImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('SELECIONAR all_trails.json (array)'),
                    onPressed: _pickAndImport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else if (_phase == _Phase.loading) ...[
                Text(
                  'Importando trilhas...',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _total > 0 ? _done / _total : 0,
                  backgroundColor: AppColors.card,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_done / $_total',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                Icon(
                  _failed == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: _failed == 0 ? Colors.green : AppColors.orange,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  _failed == 0 ? 'Importação concluída!' : 'Importação com erros',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _statRow(Icons.check, '$_success trilhas importadas', Colors.green),
                if (_failed > 0) ...[
                  const SizedBox(height: 6),
                  _statRow(Icons.close, '$_failed com erro', AppColors.error),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('FECHAR'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }
}

enum _Phase { idle, loading, done }

// ─── EBOOK IMPORT DIALOG ─────────────────────────────────────────────────────
class _EbookImportDialog extends StatefulWidget {
  final WidgetRef ref;
  const _EbookImportDialog({required this.ref});

  @override
  State<_EbookImportDialog> createState() => _EbookImportDialogState();
}

class _EbookImportDialogState extends State<_EbookImportDialog> {
  final _jsonCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      setState(() => _errorMsg = 'Não foi possível ler o arquivo.');
      return;
    }
    try {
      _jsonCtrl.text = utf8.decode(bytes);
      setState(() => _errorMsg = null);
    } catch (e) {
      setState(() => _errorMsg = 'Arquivo inválido: $e');
    }
  }

  Future<void> _import() async {
    final raw = _jsonCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMsg = 'Cole ou selecione um arquivo JSON.');
      return;
    }
    Map<String, dynamic> jsonMap;
    try {
      jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      setState(() => _errorMsg = 'JSON inválido: $e');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final ok = await widget.ref
          .read(adminControllerProvider.notifier)
          .importEbookFromJSON(jsonMap);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-book importado com sucesso!')),
        );
      } else {
        final err = widget.ref.read(adminControllerProvider).errorMessage;
        setState(() => _errorMsg = err ?? 'Erro desconhecido ao importar e-book');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book, color: Color(0xFF2DD4BF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Importar E-book',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Cole o JSON gerado pela Edu E-booker ou selecione o arquivo ebook_*.json.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TextField(
                  controller: _jsonCtrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '{\n  "category": "...",\n  "module": "...",\n  "ebookTitle": "...",\n  "sections": [...]\n}',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                ),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('SELECIONAR ARQUIVO'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _import,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.upload, size: 18),
                      label: Text(_isLoading ? 'IMPORTANDO...' : 'IMPORTAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2DD4BF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DELETE ALL CONTENT DIALOG ───────────────────────────────────────────────
class _DeleteAllContentDialog extends StatefulWidget {
  final WidgetRef ref;
  const _DeleteAllContentDialog({required this.ref});

  @override
  State<_DeleteAllContentDialog> createState() => _DeleteAllContentDialogState();
}

class _DeleteAllContentDialogState extends State<_DeleteAllContentDialog> {
  _Phase _phase = _Phase.idle;
  int _done = 0;
  int _total = 0;
  int _success = 0;
  int _failed = 0;
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    setState(() => _phase = _Phase.loading);
    final counts = await widget.ref
        .read(adminControllerProvider.notifier)
        .deleteAllContent(
          onProgress: (done, total) {
            if (mounted) {
              setState(() {
                _done = done;
                _total = total;
              });
            }
          },
        );
    if (mounted) {
      setState(() {
        _phase = _Phase.done;
        _success = counts['success'] ?? 0;
        _failed = counts['failed'] ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _confirmCtrl.text.trim().toUpperCase() == 'LIMPAR';
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 26),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Limpar Todo o Conteúdo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_phase != _Phase.loading)
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textSecondary),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (_phase == _Phase.idle) ...[
                const Text(
                  'Esta ação remove TODAS as categorias, módulos, trilhas, lições e questões do Firestore. Esta operação NÃO PODE ser desfeita.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Digite LIMPAR para confirmar:',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'LIMPAR',
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        child: const Text('CANCELAR',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canConfirm ? _execute : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('LIMPAR TUDO'),
                      ),
                    ),
                  ],
                ),
              ] else if (_phase == _Phase.loading) ...[
                Text(
                  'Removendo categorias...',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _total > 0 ? _done / _total : 0,
                  backgroundColor: AppColors.card,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.error),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_done / $_total',
                  style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ] else ...[
                Icon(
                  _failed == 0
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: _failed == 0 ? Colors.green : AppColors.orange,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  _failed == 0
                      ? 'Limpeza concluída!'
                      : 'Limpeza com erros',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('$_success categorias removidas',
                    style: const TextStyle(
                        color: Colors.green, fontSize: 14)),
                if (_failed > 0)
                  Text('$_failed com erro',
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 14)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('FECHAR'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
