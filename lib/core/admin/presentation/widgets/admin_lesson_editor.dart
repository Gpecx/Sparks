import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'admin_entity_form.dart';
import 'admin_content_panel.dart';

/// Widget para editar lições com suporte a múltiplas questões
class AdminLessonEditor extends StatefulWidget {
  final DocumentReference lessonRef;
  final String lessonTitle;
  final String lessonType; // 'lesson' ou 'eval'
  final VoidCallback? onUpdate;

  const AdminLessonEditor({
    super.key,
    required this.lessonRef,
    required this.lessonTitle,
    required this.lessonType,
    this.onUpdate,
  });

  @override
  State<AdminLessonEditor> createState() => _AdminLessonEditorState();
}

class _AdminLessonEditorState extends State<AdminLessonEditor> {
  bool _expandedQuestions = false;

  Future<void> _addQuestion() async {
    final questionsSnap = await widget.lessonRef
        .collection(FS.questions)
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder = questionsSnap.docs.isEmpty
        ? 0
        : (questionsSnap.docs.first['order'] as int? ?? 0) + 1;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AdminEntityForm(
        title: 'Nova Questão',
        fields: questionFields,
        initialValues: const {},
        onSave: (data) async {
          final processed = <String, dynamic>{};
          final type = data['type'] as String? ?? '';
          if (type == 'multipleChoice') {
            processed['options'] = [
              data['_optA'] ?? 'Opção A',
              data['_optB'] ?? 'Opção B',
              data['_optC'] ?? 'Opção C',
              data['_optD'] ?? 'Opção D',
            ];
          } else if (type == 'trueFalse') {
            processed['options'] = ['Verdadeiro', 'Falso'];
          }
          processed['type'] = type;
          if (data.containsKey('correctIndex')) {
            processed['correctIndex'] =
                int.tryParse(data['correctIndex'].toString()) ?? 0;
          }
          processed['difficulty'] = data['difficulty'] ?? 'medium';
          processed['statement'] = data['statement'] ?? '';
          processed['explanation'] = data['explanation'] ?? '';

          await widget.lessonRef.collection(FS.questions).add({
            ...processed,
            'order': nextOrder,
            FS.createdAt: FieldValue.serverTimestamp(),
          });
          if (mounted) widget.onUpdate?.call();
          return 'ok';
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  widget.lessonType == 'eval'
                      ? Icons.assignment_outlined
                      : Icons.menu_book_outlined,
                  color: widget.lessonType == 'eval'
                      ? AppColors.accentGreen
                      : AppColors.blue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lessonTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.lessonType == 'eval' ? 'Avaliação' : 'Lição',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () =>
                      setState(() => _expandedQuestions = !_expandedQuestions),
                  child: Icon(
                    _expandedQuestions ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Questões
          if (_expandedQuestions) ...[
            const Divider(color: AppColors.cardBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questões',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: widget.lessonRef
                        .collection(FS.questions)
                        .orderBy('order')
                        .snapshots(),
                    builder: (ctx, snap) {
                      final questions = snap.data?.docs ?? [];
                      if (questions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Nenhuma questão ainda.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: questions.map((q) {
                          final qData = q.data() as Map<String, dynamic>;
                          final stmt = qData['statement'] as String? ?? '—';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.cardBorder.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${qData['order'] ?? 0}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stmt.length > 50
                                              ? '${stmt.substring(0, 50)}…'
                                              : stmt,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (qData['type'] != null)
                                          Text(
                                            qData['type'],
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton(
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.edit, size: 16),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                        onTap: () => _editQuestion(q),
                                      ),
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 16,
                                              color: AppColors.error,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Deletar',
                                              style: TextStyle(
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () => _deleteQuestion(q),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Adicionar Questão'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editQuestion(QueryDocumentSnapshot qDoc) async {
    final data = qDoc.data() as Map<String, dynamic>;
    final opts = data['options'] as List? ?? [];
    final merged = <String, String>{
      'statement': data['statement']?.toString() ?? '',
      'type': data['type']?.toString() ?? '',
      '_optA': opts.isNotEmpty ? opts[0].toString() : '',
      '_optB': opts.length > 1 ? opts[1].toString() : '',
      '_optC': opts.length > 2 ? opts[2].toString() : '',
      '_optD': opts.length > 3 ? opts[3].toString() : '',
      'correctIndex': (data['correctIndex'] ?? 0).toString(),
      'difficulty': data['difficulty']?.toString() ?? 'medium',
      'explanation': data['explanation']?.toString() ?? '',
    };

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AdminEntityForm(
        title: 'Editar Questão',
        fields: questionFields,
        initialValues: merged,
        onSave: (d) async {
          final processed = <String, dynamic>{};
          final type = d['type'] as String? ?? '';
          if (type == 'multipleChoice') {
            processed['options'] = [
              d['_optA'] ?? 'Opção A',
              d['_optB'] ?? 'Opção B',
              d['_optC'] ?? 'Opção C',
              d['_optD'] ?? 'Opção D',
            ];
          } else if (type == 'trueFalse') {
            processed['options'] = ['Verdadeiro', 'Falso'];
          }
          processed['type'] = type;
          if (d.containsKey('correctIndex')) {
            processed['correctIndex'] =
                int.tryParse(d['correctIndex'].toString()) ?? 0;
          }
          processed['difficulty'] = d['difficulty'] ?? 'medium';
          processed['statement'] = d['statement'] ?? '';
          processed['explanation'] = d['explanation'] ?? '';

          await widget.lessonRef.collection(FS.questions).doc(qDoc.id).update({
            ...processed,
            FS.updatedAt: FieldValue.serverTimestamp(),
          });
          if (mounted) widget.onUpdate?.call();
          return '';
        },
      ),
    );
  }

  Future<void> _deleteQuestion(QueryDocumentSnapshot qDoc) async {
    final data = qDoc.data() as Map<String, dynamic>;
    final stmt = (data['statement'] as String? ?? '').substring(0, 40);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Deletar Questão',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deletar "$stmt..."?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () async {
              await widget.lessonRef
                  .collection(FS.questions)
                  .doc(qDoc.id)
                  .delete();
              if (mounted) {
                Navigator.pop(context);
                widget.onUpdate?.call();
              }
            },
            child: const Text(
              'DELETAR',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
