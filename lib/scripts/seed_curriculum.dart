import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/fs.dart';
import '../data/lessons_registry.dart';
import '../models/quiz_models.dart';

// ─────────────────────────────────────────────────────────────────
//  SEED: LIÇÕES + QUESTÕES → Firestore
//  Execute UMA ÚNICA VEZ por ambiente (dev/prod).
//
//  ⚠️ REQUER: usuário autenticado com role = "admin" no Firestore.
//  Para conceder: Firebase Console → users/{uid} → role: "admin"
// ─────────────────────────────────────────────────────────────────

/// Converte um [Question] para Map pronto para o Firestore.
Map<String, dynamic> _questionToMap(Question q, int order) {
  final base = <String, dynamic>{
    FS.id: q.id,
    FS.statement: q.statement,
    FS.explanation: q.explanation,
    FS.order: order,
    FS.type: q.type.name, // 'multipleChoice' | 'trueFalse' | 'fillInTheBlanks'
    FS.isActive: true,
  };

  if (q is MultipleChoice) {
    base[FS.options] = q.options;
    base[FS.correctIndex] = q.correctIndex;
  } else if (q is TrueFalse) {
    base[FS.isTrue] = q.isTrue;
  } else if (q is FillInTheBlanks) {
    base[FS.textWithBlanks] = q.textWithBlanks;
    base[FS.blanks] = q.blanks
        .map((b) => {'index': b.index, 'answer': b.answer})
        .toList();
  }

  return base;
}

/// Popula o Firestore com todas as lições e questões do [lessonsRegistry].
///
/// Estrutura:
/// `categories/{catId}/modules/{modId}/lessons/{lessonId}/questions/{qId}`
///
/// ⚠️ REQUER: usuário com `role = "admin"` no Firestore.
Future<void> seedLessonsAndQuestions({
  String catId = 'capacitacao_tecnica',
}) async {
  final fs = FirebaseFirestore.instance;

  debugPrint('[Seed] ▶ Iniciando seed → categoria: $catId');
  debugPrint('[Seed] Módulos encontrados: ${lessonsRegistry.keys.join(', ')}');

  int totalLessons = 0;
  int totalQuestions = 0;

  for (final entry in lessonsRegistry.entries) {
    final modId = entry.key;
    final lessons = entry.value;
    debugPrint('[Seed] → Módulo "$modId": ${lessons.length} lições');

    var currentBatch = fs.batch();
    int opCount = 0;

    // Commita o batch corrente e reinicia
    Future<void> flush() async {
      if (opCount == 0) return;
      debugPrint('[Seed] Commitando $opCount ops ao Firestore...');
      try {
        await currentBatch.commit().timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw SeedException(
            'Timeout (30s) ao gravar no Firestore.\n\n'
            'Verifique se seu usuário tem role="admin":\n'
            'Firebase Console → users/{seu-uid} → adicione campo: role = "admin"',
          ),
        );
      } on FirebaseException catch (e) {
        throw SeedException(
          'Erro Firestore [${e.code}]: ${e.message}\n\n'
          'Se for PERMISSION_DENIED: vá ao Firebase Console → users/{seu-uid}\n'
          'e adicione o campo: role = "admin"',
        );
      }
      currentBatch = fs.batch();
      opCount = 0;
      debugPrint('[Seed] ✓ Batch commitado.');
    }

    for (int li = 0; li < lessons.length; li++) {
      final lesson = lessons[li];
      final lessonRef = fs
          .collection(FS.categories)
          .doc(catId)
          .collection(FS.modules)
          .doc(modId)
          .collection(FS.lessons)
          .doc(lesson.id);

      currentBatch.set(lessonRef, {
        FS.id: lesson.id,
        'title': lesson.title,
        'subtitle': lesson.subtitle,
        'content': lesson.content,
        FS.order: li,
        FS.type: lesson.isEvaluation ? 'eval' : 'lesson',
        FS.isActive: true,
      });
      opCount++;
      totalLessons++;

      for (int qi = 0; qi < lesson.questions.length; qi++) {
        final q = lesson.questions[qi];
        currentBatch.set(
          lessonRef.collection(FS.questions).doc(q.id),
          _questionToMap(q, qi),
        );
        opCount++;
        totalQuestions++;
        if (opCount >= 400) await flush();
      }

      if (opCount >= 400) await flush();
    }

    await flush(); // commit final do módulo
    debugPrint('[Seed] ✅ Módulo "$modId" gravado!');
  }

  debugPrint(
    '[Seed] 🎉 CONCLUÍDO: $totalLessons lições + $totalQuestions questões '
    'em categories/$catId/',
  );
}

/// Exceção do seed com mensagem legível para o usuário.
class SeedException implements Exception {
  final String message;
  const SeedException(this.message);
  @override
  String toString() => message;
}
