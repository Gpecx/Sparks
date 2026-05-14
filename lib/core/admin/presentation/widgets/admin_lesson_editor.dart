import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'admin_entity_form.dart';

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
    final questionsSnap = await widget.lessonRef.collection(FS.questions).orderBy('order', descending: true).limit(1).get();
    final nextOrder = questionsSnap.docs.isEmpty ? 0 : (questionsSnap.docs.first['order'] as int? ?? 0) + 1;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AdminEntityForm(
        title: 'Nova Questão',
        fields: const [
          FieldConfig(key: 'statement', label: 'Enunciado', maxLines: 3),
          FieldConfig(key: 'type', label: 'Tipo', hint: 'multipleChoice | trueFalse | fillInTheBlanks'),
          FieldConfig(key: 'options', label: 'Opções (A|B|C|D)', hint: 'A|B|C|D', required: false),
          FieldConfig(key: 'correctIndex', label: 'Índice correto (0-based)', hint: '0', required: false),
          FieldConfig(key: 'difficulty', label: 'Dificuldade (easy|medium|hard)', required: false),
          FieldConfig(key: 'explanation', label: 'Explicação', maxLines: 3),
        ],
        onSave: (data) async {
          final processed = <String, dynamic>{...data};
          if (processed.containsKey('correctIndex')) {
            processed['correctIndex'] = int.tryParse(processed['correctIndex'].toString()) ?? 0;
          }
          if (processed.containsKey('options') && processed['options'] is String) {
            final str = processed['options'] as String;
            processed['options'] = str.isNotEmpty ? str.split('|').map((e) => e.trim()).toList() : <String>[];
          }
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
                  widget.lessonType == 'eval' ? Icons.assignment_outlined : Icons.menu_book_outlined,
                  color: widget.lessonType == 'eval' ? AppColors.accentGreen : AppColors.blue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.lessonTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(widget.lessonType == 'eval' ? 'Avaliação' : 'Lição', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _expandedQuestions = !_expandedQuestions),
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
                  Text('Questões', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: widget.lessonRef.collection(FS.questions).orderBy('order').snapshots(),
                    builder: (ctx, snap) {
                      final questions = snap.data?.docs ?? [];
                      if (questions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('Nenhuma questão ainda.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                                border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text('${qData['order'] ?? 0}', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(stmt.length > 50 ? '${stmt.substring(0, 50)}…' : stmt, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        if (qData['type'] != null)
                                          Text(qData['type'], style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton(
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        child: const Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Editar')]),
                                        onTap: () => _editQuestion(q),
                                      ),
                                      PopupMenuItem(
                                        child: const Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Deletar', style: TextStyle(color: AppColors.error))]),
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
    final merged = <String, String>{
      ...data.map((k, v) {
        if (k == 'options' && v is List) return MapEntry(k, (v as List).join('|'));
        return MapEntry(k, v?.toString() ?? '');
      }),
    };

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AdminEntityForm(
        title: 'Editar Questão',
        fields: const [
          FieldConfig(key: 'statement', label: 'Enunciado', maxLines: 3),
          FieldConfig(key: 'type', label: 'Tipo', hint: 'multipleChoice | trueFalse | fillInTheBlanks'),
          FieldConfig(key: 'options', label: 'Opções (A|B|C|D)', hint: 'A|B|C|D', required: false),
          FieldConfig(key: 'correctIndex', label: 'Índice correto (0-based)', hint: '0', required: false),
          FieldConfig(key: 'difficulty', label: 'Dificuldade (easy|medium|hard)', required: false),
          FieldConfig(key: 'explanation', label: 'Explicação', maxLines: 3),
        ],
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
        title: const Text('Deletar Questão', style: TextStyle(color: Colors.white)),
        content: Text('Deletar "$stmt..."?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              await widget.lessonRef.collection(FS.questions).doc(qDoc.id).delete();
              if (mounted) {
                Navigator.pop(context);
                widget.onUpdate?.call();
              }
            },
            child: const Text('DELETAR', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
