import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  FIELD TYPE ENUM
// ─────────────────────────────────────────────────────────────────

enum FieldType { text, dropdown, staticDropdown }

// ─────────────────────────────────────────────────────────────────
//  FIELD CONFIG
// ─────────────────────────────────────────────────────────────────

class FieldConfig {
  final String key;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  /// Texto do tooltip mostrado ao passar o mouse sobre o label
  final String? tooltip;

  // Dropdown-specific (Firestore)
  final FieldType fieldType;
  final String? dropdownCollection;
  final String? dropdownSubCollection;
  final String? dropdownParentKeyRef;
  final String dropdownLabelField;
  final bool dropdownUseCollectionGroup;
  final String? dropdownGroupFilterField;

  // Static dropdown (opções fixas: [valor, labelExibido])
  final List<(String value, String label)> staticOptions;

  // Condicional: só mostra este campo se [dependsOnKey] tiver valor [dependsOnValue]
  final String? dependsOnKey;
  final String? dependsOnValue;

  const FieldConfig({
    required this.key,
    required this.label,
    this.hint = '',
    this.required = true,
    this.maxLines = 1,
    this.keyboardType,
    this.tooltip,
    this.fieldType = FieldType.text,
    this.dropdownCollection,
    this.dropdownSubCollection,
    this.dropdownParentKeyRef,
    this.dropdownLabelField = 'title',
    this.dropdownUseCollectionGroup = false,
    this.dropdownGroupFilterField,
    this.staticOptions = const [],
    this.dependsOnKey,
    this.dependsOnValue,
  });
}

// ─────────────────────────────────────────────────────────────────
//  ADMIN ENTITY FORM
// ─────────────────────────────────────────────────────────────────

class AdminEntityForm extends StatefulWidget {
  final String title;
  final List<FieldConfig> fields;
  final Map<String, String> initialValues;
  /// Returns the new document ID on success (empty string for non-create ops).
  final Future<String> Function(Map<String, dynamic> data) onSave;

  const AdminEntityForm({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.initialValues = const {},
  });

  @override
  State<AdminEntityForm> createState() => _AdminEntityFormState();
}

class _AdminEntityFormState extends State<AdminEntityForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _textControllers;
  final Map<String, String?> _dropdownValues = {};
  bool _isSaving = false;
  bool _showSuccess = false;
  String? _lastCreatedId;

  @override
  void initState() {
    super.initState();
    _textControllers = {
      for (final f in widget.fields.where((f) => f.fieldType == FieldType.text))
        f.key: TextEditingController(text: widget.initialValues[f.key] ?? ''),
    };
    for (final f in widget.fields.where(
        (f) => f.fieldType == FieldType.dropdown || f.fieldType == FieldType.staticDropdown)) {
      final init = widget.initialValues[f.key];
      _dropdownValues[f.key] = (init != null && init.isNotEmpty) ? init : null;
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Query builder ─────────────────────────────────────────────
  Stream<QuerySnapshot>? _buildStream(FieldConfig f) {
    final db = FirebaseFirestore.instance;

    // Top-level collection (no parent)
    if (f.dropdownParentKeyRef == null) {
      final col = f.dropdownCollection;
      if (col == null) return null;
      return db.collection(col).snapshots();
    }

    final parentId = _dropdownValues[f.dropdownParentKeyRef!];
    if (parentId == null || parentId.isEmpty) return null;

    // collectionGroup with filter
    if (f.dropdownUseCollectionGroup) {
      final filterField = f.dropdownGroupFilterField;
      if (filterField == null || f.dropdownCollection == null) return null;
      return db
          .collectionGroup(f.dropdownCollection!)
          .where(filterField, isEqualTo: parentId)
          .snapshots();
    }

    // Subcollection: collection(parent).doc(parentId).collection(sub)
    if (f.dropdownCollection != null && f.dropdownSubCollection != null) {
      return db
          .collection(f.dropdownCollection!)
          .doc(parentId)
          .collection(f.dropdownSubCollection!)
          .snapshots();
    }

    return null;
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required dropdowns manually
    for (final f in widget.fields.where((f) => f.fieldType == FieldType.dropdown && f.required)) {
      if (_dropdownValues[f.key] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${f.label} é obrigatório'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Build data map
    final raw = <String, dynamic>{};
    for (final f in widget.fields) {
      // Ignorar campos condicionais que não estão visíveis
      if (f.dependsOnKey != null) {
        final parentVal = _dropdownValues[f.dependsOnKey!];
        if (parentVal != f.dependsOnValue) continue;
      }
      if (f.fieldType == FieldType.text) {
        raw[f.key] = _textControllers[f.key]!.text.trim();
      } else {
        raw[f.key] = _dropdownValues[f.key] ?? '';
      }
    }

    // Strip internal _ prefixed keys
    final clean = Map<String, dynamic>.fromEntries(
      raw.entries.where((e) => !e.key.startsWith('_')),
    );

    setState(() => _isSaving = true);
    try {
      debugPrint('ADMIN_FORM: Iniciando salvamento...');
      // O Firestore confirma escritas localmente mesmo offline,
      // não use timeout aqui — ele causa falso erro de "conexão".
      final docId = await widget.onSave(clean);
      
      debugPrint('ADMIN_FORM: Sucesso! ID: $docId');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSuccess = true;
          _lastCreatedId = docId;
        });
      }
    } catch (e) {
      debugPrint('ADMIN_FORM: Erro: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    }
    // REMOVIDO: o bloco finally que chamava setState novamente após o catch
    // já ter feito o mesmo — causava double-setState e podia sobrescrever
    // o _showSuccess = true setado no try.
  }

  // ── Build dropdown field ──────────────────────────────────────
  Widget _buildDropdown(FieldConfig f) {
    final stream = _buildStream(f);

    if (stream == null) {
      // Parent not yet selected
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            f.label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: null,
            decoration: InputDecoration(
              fillColor: AppColors.card.withValues(alpha: 0.5),
              hintText: f.dropdownParentKeyRef != null
                  ? 'Selecione ${f.label.toLowerCase()} primeiro'
                  : 'Carregando...',
            ),
            items: const [],
            onChanged: null,
            validator: f.required
                ? (_) => _dropdownValues[f.key] == null ? '${f.label} é obrigatório' : null
                : null,
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final items = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final label = data[f.dropdownLabelField]?.toString() ?? doc.id;
          return DropdownMenuItem<String>(value: doc.id, child: Text(label));
        }).toList();

        // Reset value if no longer valid
        final currentVal = _dropdownValues[f.key];
        final validVal = items.any((i) => i.value == currentVal) ? currentVal : null;
        if (validVal != currentVal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _dropdownValues[f.key] = null);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              f.label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: validVal,
              decoration: InputDecoration(
                fillColor: AppColors.card.withValues(alpha: 0.5),
                hintText: snap.connectionState == ConnectionState.waiting
                    ? 'Carregando...'
                    : 'Selecione ${f.label.toLowerCase()}',
              ),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              items: items,
              onChanged: snap.connectionState == ConnectionState.waiting
                  ? null
                  : (val) {
                      setState(() {
                        _dropdownValues[f.key] = val;
                        // Clear children dropdowns that depend on this key
                        for (final child in widget.fields
                            .where((c) => c.dropdownParentKeyRef == f.key)) {
                          _dropdownValues[child.key] = null;
                        }
                      });
                    },
              validator: f.required
                  ? (_) => _dropdownValues[f.key] == null ? '${f.label} é obrigatório' : null
                  : null,
            ),
          ],
        );
      },
    );
  }

  // ── Label with tooltip ───────────────────────────────────────
  Widget _buildLabelWithTooltip(FieldConfig f) {
    final label = Text(
      f.label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
    if (f.tooltip == null || f.tooltip!.isEmpty) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        const SizedBox(width: 4),
        Tooltip(
          message: f.tooltip!,
          preferBelow: false,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          child: const Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // ── Static dropdown (opções fixas) ───────────────────────────
  Widget _buildStaticDropdown(FieldConfig f) {
    final currentVal = _dropdownValues[f.key];
    final validVal = f.staticOptions.any((o) => o.$1 == currentVal) ? currentVal : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildLabelWithTooltip(f),
            if (f.required)
              const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: validVal,
          decoration: InputDecoration(
            fillColor: AppColors.card.withValues(alpha: 0.5),
            hintText: 'Selecione ${f.label.toLowerCase()}',
            filled: true,
          ),
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary),
          items: f.staticOptions.map((o) {
            return DropdownMenuItem<String>(
              value: o.$1,
              child: Text(o.$2),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _dropdownValues[f.key] = val;
              // Limpar campos dependentes
              for (final child in widget.fields.where((c) => c.dependsOnKey == f.key)) {
                _dropdownValues[child.key] = null;
              }
            });
          },
          validator: f.required
              ? (_) => _dropdownValues[f.key] == null ? '${f.label} é obrigatório' : null
              : null,
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
          child: _showSuccess ? _buildSuccessView() : _buildFormView(context, isDesktop),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context, bool isDesktop) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // ── Header Gradient ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.title.contains('Categoria') 
                      ? Icons.category_outlined 
                      : widget.title.contains('Módulo') 
                          ? Icons.view_module_outlined 
                          : Icons.auto_awesome_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Preencha os detalhes abaixo',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Botão de fechar — sempre habilitado, mesmo durante o salvamento
              Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    debugPrint('ADMIN_FORM: Botão X pressionado');
                    // rootNavigator: true garante fechar o Dialog mesmo com
                    // contextos aninhados ou durante _isSaving
                    Navigator.of(context, rootNavigator: true).pop(false);
                  },
                  tooltip: 'Fechar',
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
                  // ── Fields ───────────────────────────────────────
                  ...widget.fields.map((f) {
                        // Campo condicional: verificar se deve ser exibido
                        if (f.dependsOnKey != null) {
                          final parentVal = _dropdownValues[f.dependsOnKey!];
                          if (parentVal != f.dependsOnValue) {
                            return const SizedBox.shrink();
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: f.fieldType == FieldType.dropdown
                              ? _buildDropdown(f)
                              : f.fieldType == FieldType.staticDropdown
                                  ? _buildStaticDropdown(f)
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildLabelWithTooltip(f),
                                            if (f.required)
                                              const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 10)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _textControllers[f.key],
                                          maxLines: f.maxLines,
                                          keyboardType: f.keyboardType,
                                          style: const TextStyle(color: AppColors.textPrimary),
                                          decoration: InputDecoration(
                                            hintText: f.hint.isNotEmpty ? f.hint : 'Digite aqui...',
                                            fillColor: AppColors.card.withValues(alpha: 0.5),
                                            prefixIcon: f.key.contains('icon') ? const Icon(Icons.insert_emoticon, size: 20, color: AppColors.textMuted) : null,
                                          ),
                                          validator: f.required
                                              ? (v) => (v == null || v.trim().isEmpty)
                                                  ? '${f.label} é obrigatório'
                                                  : null
                                              : null,
                                        ),
                                      ],
                                    ),
                        );
                      }),
                  const SizedBox(height: 12),
                  // ── Actions ──────────────────────────────────────
                  Row(
                    children: [
                      if (!_isSaving)
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
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
                              backgroundColor: AppColors.primary,
                              elevation: 8,
                              shadowColor: AppColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 3),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check, size: 20),
                                      const SizedBox(width: 12),
                                      Text('FINALIZAR'),
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
          Text(
            '${widget.title} concluída!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'As informações foram salvas com sucesso no banco de dados do SPARK.',
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
                      _textControllers.values.forEach((c) => c.clear());
                      _dropdownValues.keys.forEach((k) => _dropdownValues[k] = null);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('CRIAR OUTRO', style: TextStyle(color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(_lastCreatedId),
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

// ─────────────────────────────────────────────────────────────────
//  SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────────

class AdminSuccessDialog extends StatefulWidget {
  final String message;
  const AdminSuccessDialog({super.key, this.message = 'Criado com sucesso!'});

  @override
  State<AdminSuccessDialog> createState() => _AdminSuccessDialogState();
}

class _AdminSuccessDialogState extends State<AdminSuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeIn)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
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
                const SizedBox(height: 28),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tudo pronto para o próximo passo!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('ÓTIMO!'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}