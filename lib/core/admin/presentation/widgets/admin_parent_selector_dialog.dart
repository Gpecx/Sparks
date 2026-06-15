import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  PARENT SELECTION RESULT
// ─────────────────────────────────────────────────────────────────

class ParentSelection {
  final String? categoryId;
  final String? categoryName;
  final String? moduleId;
  final String? moduleName;
  final String? trailId;
  final String? trailName;
  final String? lessonId;
  final String? lessonName;

  const ParentSelection({
    this.categoryId,
    this.categoryName,
    this.moduleId,
    this.moduleName,
    this.trailId,
    this.trailName,
    this.lessonId,
    this.lessonName,
  });
}

// ─────────────────────────────────────────────────────────────────
//  ADMIN PARENT SELECTOR DIALOG
//
//  Uso:
//    - Para Módulo:  levels = ['category']
//    - Para Trilha:  levels = ['category', 'module']  (já usa o wizard)
//    - Para Lição:   levels = ['category', 'module', 'trail']
//    - Para Questão: levels = ['category', 'module', 'trail', 'lesson']
// ─────────────────────────────────────────────────────────────────

class AdminParentSelectorDialog extends StatefulWidget {
  /// Quais níveis mostrar: subconjunto de ['category','module','trail','lesson']
  final List<String> levels;
  final String title;

  const AdminParentSelectorDialog({
    super.key,
    required this.levels,
    required this.title,
  });

  @override
  State<AdminParentSelectorDialog> createState() =>
      _AdminParentSelectorDialogState();
}

class _AdminParentSelectorDialogState
    extends State<AdminParentSelectorDialog> {
  final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  String? _categoryId;
  String? _categoryName;
  String? _moduleId;
  String? _moduleName;
  String? _trailId;
  String? _trailName;
  String? _lessonId;
  String? _lessonName;

  bool get _canConfirm {
    if (widget.levels.contains('category') && _categoryId == null) return false;
    if (widget.levels.contains('module') && _moduleId == null) return false;
    if (widget.levels.contains('trail') && _trailId == null) return false;
    if (widget.levels.contains('lesson') && _lessonId == null) return false;
    return true;
  }

  void _confirm() {
    Navigator.of(context).pop(ParentSelection(
      categoryId: _categoryId,
      categoryName: _categoryName,
      moduleId: _moduleId,
      moduleName: _moduleName,
      trailId: _trailId,
      trailName: _trailName,
      lessonId: _lessonId,
      lessonName: _lessonName,
    ));
  }

  // ── Dropdown genérico via Stream ───────────────────────────────
  Widget _buildStreamDropdown({
    required String label,
    required IconData icon,
    required Stream<QuerySnapshot> stream,
    required String? value,
    required void Function(String id, String name) onSelected,
    required void Function() onReset,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final isLoading = snap.connectionState == ConnectionState.waiting;

        // valida que o valor atual ainda existe
        final validValue =
            docs.any((d) => d.id == value) ? value : null;
        if (validValue != value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) onReset();
          });
        }

        return _SelectorDropdown(
          label: label,
          icon: icon,
          hint: isLoading ? 'Carregando...' : 'Selecione $label',
          value: validValue,
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = data['title']?.toString() ?? d.id;
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
            );
          }).toList(),
          onChanged: isLoading
              ? null
              : (val) {
                  if (val == null) return;
                  final doc = docs.firstWhere((d) => d.id == val);
                  final data = doc.data() as Map<String, dynamic>;
                  onSelected(val, data['title']?.toString() ?? val);
                },
        );
      },
    );
  }

  // ── Categoria ──────────────────────────────────────────────────
  Widget _buildCategoryDropdown() {
    return _buildStreamDropdown(
      label: 'Categoria',
      icon: Icons.category_outlined,
      stream: _db.collection(FS.categories).snapshots(),
      value: _categoryId,
      onSelected: (id, name) => setState(() {
        _categoryId = id;
        _categoryName = name;
        _moduleId = null;
        _moduleName = null;
        _trailId = null;
        _trailName = null;
        _lessonId = null;
        _lessonName = null;
      }),
      onReset: () => setState(() {
        _categoryId = null;
        _categoryName = null;
        _moduleId = null;
        _moduleName = null;
        _trailId = null;
        _trailName = null;
        _lessonId = null;
        _lessonName = null;
      }),
    );
  }

  // ── Módulo ─────────────────────────────────────────────────────
  Widget _buildModuleDropdown() {
    if (_categoryId == null) {
      return _SelectorDropdown(
        label: 'Módulo',
        icon: Icons.layers_outlined,
        hint: 'Selecione a categoria primeiro',
        value: null,
        items: const [],
        onChanged: null,
      );
    }
    return _buildStreamDropdown(
      label: 'Módulo',
      icon: Icons.layers_outlined,
      stream: _db
          .collection(FS.categories)
          .doc(_categoryId)
          .collection(FS.modules)
          .snapshots(),
      value: _moduleId,
      onSelected: (id, name) => setState(() {
        _moduleId = id;
        _moduleName = name;
        _trailId = null;
        _trailName = null;
        _lessonId = null;
        _lessonName = null;
      }),
      onReset: () => setState(() {
        _moduleId = null;
        _moduleName = null;
        _trailId = null;
        _trailName = null;
        _lessonId = null;
        _lessonName = null;
      }),
    );
  }

  // ── Trilha ─────────────────────────────────────────────────────
  Widget _buildTrailDropdown() {
    if (_categoryId == null || _moduleId == null) {
      return _SelectorDropdown(
        label: 'Trilha',
        icon: Icons.map_outlined,
        hint: 'Selecione o módulo primeiro',
        value: null,
        items: const [],
        onChanged: null,
      );
    }
    return _buildStreamDropdown(
      label: 'Trilha',
      icon: Icons.map_outlined,
      stream: _db
          .collection(FS.categories)
          .doc(_categoryId)
          .collection(FS.modules)
          .doc(_moduleId)
          .collection(FS.trails)
          .snapshots(),
      value: _trailId,
      onSelected: (id, name) => setState(() {
        _trailId = id;
        _trailName = name;
        _lessonId = null;
        _lessonName = null;
      }),
      onReset: () => setState(() {
        _trailId = null;
        _trailName = null;
        _lessonId = null;
        _lessonName = null;
      }),
    );
  }

  // ── Lição ──────────────────────────────────────────────────────
  Widget _buildLessonDropdown() {
    if (_categoryId == null || _moduleId == null || _trailId == null) {
      return _SelectorDropdown(
        label: 'Lição',
        icon: Icons.menu_book_outlined,
        hint: 'Selecione a trilha primeiro',
        value: null,
        items: const [],
        onChanged: null,
      );
    }
    return _buildStreamDropdown(
      label: 'Lição',
      icon: Icons.menu_book_outlined,
      stream: _db
          .collection(FS.categories)
          .doc(_categoryId)
          .collection(FS.modules)
          .doc(_moduleId)
          .collection(FS.trails)
          .doc(_trailId)
          .collection(FS.lessons)
          .snapshots(),
      value: _lessonId,
      onSelected: (id, name) => setState(() {
        _lessonId = id;
        _lessonName = name;
      }),
      onReset: () => setState(() {
        _lessonId = null;
        _lessonName = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Selecione onde criar',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Dropdowns cascata conforme os níveis configurados
            if (widget.levels.contains('category')) ...[
              _buildCategoryDropdown(),
              const SizedBox(height: 12),
            ],
            if (widget.levels.contains('module')) ...[
              _buildModuleDropdown(),
              const SizedBox(height: 12),
            ],
            if (widget.levels.contains('trail')) ...[
              _buildTrailDropdown(),
              const SizedBox(height: 12),
            ],
            if (widget.levels.contains('lesson')) ...[
              _buildLessonDropdown(),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            // Botão confirmar
            AnimatedOpacity(
              opacity: _canConfirm ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton.icon(
                onPressed: _canConfirm ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 18),
                label: const Text(
                  'Continuar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  SELECTOR DROPDOWN — widget interno estilizado
// ─────────────────────────────────────────────────────────────────

class _SelectorDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String hint;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  const _SelectorDropdown({
    required this.label,
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && items.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.cardBorder.withValues(alpha: 0.5),
          width: value != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: value != null ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                hint: Text(
                  hint,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
                dropdownColor: AppColors.card,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                items: enabled ? items : null,
                onChanged: onChanged,
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: enabled ? AppColors.textSecondary : AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accentGreen,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
