import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/admin/presentation/admin_controller.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_dialogs_new.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_entity_form.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/theme/app_theme.dart';

const _kOrange = Color(0xFFFF9800);

// ─── FIELD CONFIGS ────────────────────────────────────────────────

const _lessonFields = <FieldConfig>[
  FieldConfig(key: 'title',   label: 'Título'),
  FieldConfig(key: 'content', label: 'Conteúdo (Markdown)', maxLines: 6, required: false),
  FieldConfig(key: 'type',    label: 'Tipo (lesson | eval)', required: false),
  FieldConfig(key: 'order',   label: 'Ordem', hint: 'ex: 1', required: false, keyboardType: TextInputType.number),
];

const _questionFields = <FieldConfig>[
  FieldConfig(key: 'statement',    label: 'Enunciado', maxLines: 3),
  FieldConfig(key: 'type',         label: 'Tipo', hint: 'multipleChoice | trueFalse | fillInTheBlanks'),
  FieldConfig(key: 'options',      label: 'Opções (A|B|C|D)', hint: 'A|B|C|D', required: false),
  FieldConfig(key: 'correctIndex', label: 'Índice correto (0-based)', hint: '0', required: false, keyboardType: TextInputType.number),
  FieldConfig(key: 'difficulty',   label: 'Dificuldade (easy|medium|hard)', required: false),
  FieldConfig(key: 'explanation',  label: 'Explicação', maxLines: 3),
];

// ─── MAIN WIDGET ──────────────────────────────────────────────────

class AdminContentPanel extends ConsumerWidget {
  final String categoryId;
  final String moduleId;
  final VoidCallback? onTrailCreated;

  const AdminContentPanel({
    super.key,
    required this.categoryId,
    required this.moduleId,
    this.onTrailCreated,
  });

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<QuerySnapshot> get _trailsStream => _db
      .collection(FS.categories)
      .doc(categoryId)
      .collection(FS.modules)
      .doc(moduleId)
      .collection(FS.trails)
      .snapshots();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<QuerySnapshot>(
      stream: _trailsStream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2));
        }
        final trails = snap.data?.docs ?? [];
        if (trails.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_outlined, size: 52, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text('Nenhuma trilha', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Crie uma trilha com o botão "GERAR TRILHA"', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 8 : 16),
          itemCount: trails.length,
          itemBuilder: (_, i) => _TrailCard(
            trailDoc:   trails[i],
            categoryId: categoryId,
            moduleId:   moduleId,
          ),
        );
      },
    );
  }
}

// ─── TRAIL CARD ───────────────────────────────────────────────────

class _TrailCard extends ConsumerStatefulWidget {
  final QueryDocumentSnapshot trailDoc;
  final String categoryId;
  final String moduleId;

  const _TrailCard({required this.trailDoc, required this.categoryId, required this.moduleId});

  @override
  ConsumerState<_TrailCard> createState() => _TrailCardState();
}

class _TrailCardState extends ConsumerState<_TrailCard> {
  bool _expanded = true;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference get _trailRef => _db
      .collection(FS.categories)
      .doc(widget.categoryId)
      .collection(FS.modules)
      .doc(widget.moduleId)
      .collection(FS.trails)
      .doc(widget.trailDoc.id);

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : _kOrange,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _confirmDeleteTrail() {
    final data  = widget.trailDoc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'esta trilha';
    
    AdminDialogs.showConfirmDelete(
      context: context,
      title: 'Deletar Trilha',
      content: 'Deletar "$title" removerá todas as lições e questões vinculadas.',
      onConfirm: () async {
        await ref.read(adminControllerProvider.notifier).delete(AdminEntity.trails, widget.trailDoc.id);
        if (mounted) _showToast('Trilha deletada');
      },
    );
  }

  Future<void> _openTrailEdit() async {
    final data   = widget.trailDoc.data() as Map<String, dynamic>;
    final ctrl   = ref.read(adminControllerProvider.notifier);
    final merged = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    await showDialog<dynamic>(
      context: context,
      builder: (_) => AdminEntityForm(
        title: 'Editar Trilha',
        fields: const [FieldConfig(key: 'title', label: 'Título')],
        initialValues: Map<String, String>.from(merged),
        onSave: (d) async {
          ctrl.update(AdminEntity.trails, widget.trailDoc.id, d)
              .catchError((e) => debugPrint('Erro update trail: $e'));
          return '';
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data  = widget.trailDoc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // ── Trail Header ────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.route_outlined, color: _kOrange, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  _SmallIconBtn(icon: Icons.edit_outlined, color: AppColors.blue, onTap: _openTrailEdit),
                  _SmallIconBtn(icon: Icons.delete_outline, color: AppColors.error, onTap: _confirmDeleteTrail),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          // ── Lessons ─────────────────────────────────────────────
          if (_expanded)
            StreamBuilder<QuerySnapshot>(
              stream: _trailRef.collection(FS.lessons).orderBy('order').snapshots(),
              builder: (ctx, snap) {
                final lessons = snap.data?.docs ?? [];
                return Column(
                  children: [
                    ...lessons.map((l) => _LessonNode(
                          lessonDoc:  l,
                          trailRef:   _trailRef,
                          categoryId: widget.categoryId,
                          moduleId:   widget.moduleId,
                          trailId:    widget.trailDoc.id,
                        )),
                    // ── Add lesson button ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: _AddLessonButton(trailRef: _trailRef, nextOrder: lessons.length + 1),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── LESSON NODE ──────────────────────────────────────────────────

class _LessonNode extends ConsumerStatefulWidget {
  final QueryDocumentSnapshot lessonDoc;
  final DocumentReference     trailRef;
  final String categoryId;
  final String moduleId;
  final String trailId;

  const _LessonNode({
    required this.lessonDoc,
    required this.trailRef,
    required this.categoryId,
    required this.moduleId,
    required this.trailId,
  });

  @override
  ConsumerState<_LessonNode> createState() => _LessonNodeState();
}

class _LessonNodeState extends ConsumerState<_LessonNode> {
  bool _expandedQ = false;

  DocumentReference get _lessonRef => widget.trailRef.collection(FS.lessons).doc(widget.lessonDoc.id);

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.blue,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openLessonEdit() async {
    final data   = widget.lessonDoc.data() as Map<String, dynamic>;
    final merged = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => AdminEntityForm(
        title: 'Editar Lição',
        fields: _lessonFields,
        initialValues: Map<String, String>.from(merged),
        onSave: (d) async {
          _lessonRef.update({...d, FS.updatedAt: FieldValue.serverTimestamp()})
              .catchError((e) => debugPrint('Erro edit lesson: $e'));
          return '';
        },
      ),
    );
    if (result != null && result != false && mounted) _showToast('Lição atualizada!');
  }

  void _confirmDeleteLesson() {
    final data  = widget.lessonDoc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'esta lição';

    AdminDialogs.showConfirmDelete(
      context: context,
      title: 'Deletar Lição',
      content: 'Deletar "$title" removerá todas as questões vinculadas.',
      onConfirm: () async {
        await _lessonRef.delete();
        if (mounted) _showToast('Lição deletada');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data  = widget.lessonDoc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? '—';
    final type  = data['type'] as String? ?? 'lesson';
    final isEval = type == 'eval';
    final nodeColor = isEval ? AppColors.accentGreen : AppColors.blue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Track line ─────────────────────────────────────────
          Column(
            children: [
              Container(
                width: 2,
                height: 12,
                color: nodeColor.withValues(alpha: 0.4),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: nodeColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // ── Lesson card ────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: nodeColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  // header
                  InkWell(
                    onTap: () => setState(() => _expandedQ = !_expandedQ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Icon(isEval ? Icons.assignment_outlined : Icons.menu_book_outlined, color: nodeColor, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(title, style: TextStyle(color: nodeColor, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          _SmallIconBtn(icon: Icons.edit_outlined, color: AppColors.blue, onTap: _openLessonEdit),
                          _SmallIconBtn(icon: Icons.delete_outline, color: AppColors.error, onTap: _confirmDeleteLesson),
                          Icon(_expandedQ ? Icons.expand_less : Icons.expand_more, size: 16, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  // questions
                  if (_expandedQ)
                    _QuestionsSection(lessonRef: _lessonRef),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QUESTIONS SECTION ────────────────────────────────────────────

class _QuestionsSection extends StatelessWidget {
  final DocumentReference lessonRef;
  const _QuestionsSection({required this.lessonRef});

  Future<void> _openAddQuestion(BuildContext context, int nextOrder) async {
    await showDialog<dynamic>(
      context: context,
      builder: (_) => AdminEntityForm(
        title: 'Nova Questão',
        fields: _questionFields,
        initialValues: const {},
        onSave: (data) async {
          final processed = <String, dynamic>{...data};
          if (processed.containsKey('correctIndex')) {
            processed['correctIndex'] = int.tryParse(processed['correctIndex'].toString()) ?? 0;
          }
          if (processed.containsKey('options') && processed['options'] is String) {
            final str = processed['options'] as String;
            processed['options'] = str.isNotEmpty ? str.split('|').map((e) => e.trim()).toList() : <String>[];
          }
          lessonRef.collection(FS.questions).add({
            ...processed,
            'order': nextOrder,
            'isActive': false,
            FS.createdAt: FieldValue.serverTimestamp(),
          }).catchError((e) => debugPrint('Erro add question: $e'));
          return 'ok';
        },
      ),
    );
  }

  Future<void> _openEditQuestion(BuildContext context, DocumentSnapshot qDoc) async {
    final data   = qDoc.data() as Map<String, dynamic>;
    // convert options list → pipe-separated string for the form
    final merged = <String, String>{
      ...data.map((k, v) {
        if (k == 'options' && v is List) return MapEntry(k, (v as List).join('|'));
        return MapEntry(k, v?.toString() ?? '');
      }),
    };
    await showDialog<dynamic>(
      context: context,
      builder: (_) => AdminEntityForm(
        title: 'Editar Questão',
        fields: _questionFields,
        initialValues: merged,
        onSave: (d) async {
          final processed = <String, dynamic>{...d};
          if (processed.containsKey('correctIndex')) {
            processed['correctIndex'] = int.tryParse(processed['correctIndex'].toString()) ?? 0;
          }
          if (processed.containsKey('options') && processed['options'] is String) {
            final str = processed['options'] as String;
            processed['options'] = str.isNotEmpty ? str.split('|').map((e) => e.trim()).toList() : <String>[];
          }
          lessonRef.collection(FS.questions).doc(qDoc.id).update({
            ...processed,
            FS.updatedAt: FieldValue.serverTimestamp(),
          }).catchError((e) => debugPrint('Erro edit question: $e'));
          return '';
        },
      ),
    );
  }

  void _confirmDeleteQuestion(BuildContext context, DocumentSnapshot qDoc) {
    final data  = qDoc.data() as Map<String, dynamic>;
    final stmt  = (data['statement'] as String? ?? '').take(40);

    AdminDialogs.showConfirmDelete(
      context: context,
      title: 'Deletar Questão',
      content: 'Deletar "$stmt..."?',
      onConfirm: () async {
        await lessonRef.collection(FS.questions).doc(qDoc.id).delete();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: lessonRef.collection(FS.questions).orderBy('order').snapshots(),
      builder: (ctx, snap) {
        final qs = snap.data?.docs ?? [];
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: AppColors.cardBorder, height: 12),
              ...qs.map((q) => _QuestionRow(
                    qDoc: q,
                    onEdit: () => _openEditQuestion(context, q),
                    onDelete: () => _confirmDeleteQuestion(context, q),
                  )),
              // ── Add question ────────────────────────────────────
              GestureDetector(
                onTap: () => _openAddQuestion(context, qs.length + 1),
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, color: AppColors.primary, size: 14),
                      SizedBox(width: 4),
                      Text('Adicionar questão', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── QUESTION ROW ─────────────────────────────────────────────────

class _QuestionRow extends StatelessWidget {
  final QueryDocumentSnapshot qDoc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionRow({required this.qDoc, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final data  = qDoc.data() as Map<String, dynamic>;
    final stmt  = data['statement'] as String? ?? '—';
    final type  = data['type'] as String? ?? '';
    final order = data['order'] ?? '';
    final active = data['isActive'] as bool? ?? false;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: active ? AppColors.primary.withValues(alpha: 0.2) : AppColors.textMuted.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$order', style: TextStyle(color: active ? AppColors.primary : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stmt.length > 60 ? '${stmt.substring(0, 60)}…' : stmt, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (type.isNotEmpty)
                    Text(type, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
            _SmallIconBtn(icon: Icons.edit_outlined, color: AppColors.blue, onTap: onEdit),
            _SmallIconBtn(icon: Icons.delete_outline, color: AppColors.error, onTap: onDelete),
          ],
        ),
      ),
    );
  }
}

// ─── ADD LESSON BUTTON ────────────────────────────────────────────

class _AddLessonButton extends StatelessWidget {
  final DocumentReference trailRef;
  final int               nextOrder;
  const _AddLessonButton({required this.trailRef, required this.nextOrder});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<dynamic>(
        context: context,
        builder: (_) => AdminEntityForm(
          title: 'Nova Lição',
          fields: _lessonFields,
          initialValues: const {},
          onSave: (data) async {
            trailRef.collection(FS.lessons).add({
              ...data,
              'order': nextOrder,
              FS.createdAt: FieldValue.serverTimestamp(),
            }).catchError((e) => debugPrint('Erro add lesson: $e'));
            return 'ok';
          },
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.blue, size: 14),
            SizedBox(width: 4),
            Text('Adicionar lição', style: TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── HELPERS ──────────────────────────────────────────────────────

class _SmallIconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _SmallIconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, color: color, size: 15),
        ),
      );
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
