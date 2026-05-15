import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/core/admin/domain/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // ─── CATEGORIES ────────────────────────────────────────────────
  @override
  Stream<QuerySnapshot> categoriesStream() =>
      _fs.collection(FS.categories).orderBy(FS.order).snapshots();

  @override
  Future<void> createCategory(Map<String, dynamic> data) async {
    final doc = _fs.collection(FS.categories).doc();
    data[FS.createdAt] = FieldValue.serverTimestamp();
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    data[FS.order] = 0;
    await doc.set(data);
  }

  @override
  Future<void> updateCategory(String catId, Map<String, dynamic> data) async {
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await _fs.collection(FS.categories).doc(catId).update(data);
  }

  @override
  Future<void> deleteCategory(String catId) async {
    // Cascading deletion is usually handled via Cloud Functions in production,
    // but for this admin panel we'll do it manually here if needed.
    // Given the complexity of nested collections, we'll just delete the doc for now 
    // or implement a deep delete if required by the user.
    await _fs.collection(FS.categories).doc(catId).delete();
  }

  // ─── MODULES ───────────────────────────────────────────────────
  @override
  Stream<QuerySnapshot> modulesStream(String catId) =>
      _fs.collection(FS.categories).doc(catId).collection(FS.modules).orderBy(FS.order).snapshots();

  @override
  Future<void> createModule(String catId, Map<String, dynamic> data) async {
    final doc = _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc();
    data[FS.categoryId] = catId;
    data[FS.createdAt] = FieldValue.serverTimestamp();
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await doc.set(data);
  }

  @override
  Future<void> updateModule(String catId, String modId, Map<String, dynamic> data) async {
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).update(data);
  }

  @override
  Future<void> deleteModule(String catId, String modId) async {
    await _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).delete();
  }

  // ─── TRAILS ────────────────────────────────────────────────────
  @override
  Stream<QuerySnapshot> trailsStream(String catId, String modId) =>
      _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).orderBy(FS.order).snapshots();

  @override
  Future<void> createTrail(String catId, String modId, Map<String, dynamic> data) async {
    final doc = _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc();
    data[FS.categoryId] = catId;
    data[FS.moduleId] = modId;
    data[FS.createdAt] = FieldValue.serverTimestamp();
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await doc.set(data);
  }

  @override
  Future<void> updateTrail(String catId, String modId, String trailId, Map<String, dynamic> data) async {
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).update(data);
  }

  @override
  Future<void> deleteTrail(String catId, String modId, String trailId) async {
    await _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).delete();
  }

  // ─── LESSONS ───────────────────────────────────────────────────
  @override
  Stream<QuerySnapshot> lessonsStream(String catId, String modId, String trailId) =>
      _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).collection(FS.lessons).orderBy(FS.order).snapshots();

  @override
  Future<void> createLesson(String catId, String modId, String trailId, Map<String, dynamic> data) async {
    final doc = _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).collection(FS.lessons).doc();
    data[FS.createdAt] = FieldValue.serverTimestamp();
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await doc.set(data);
  }

  @override
  Future<void> updateLesson(String catId, String modId, String trailId, String lessonId, Map<String, dynamic> data) async {
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).collection(FS.lessons).doc(lessonId).update(data);
  }

  @override
  Future<void> deleteLesson(String catId, String modId, String trailId, String lessonId) async {
    await _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).collection(FS.lessons).doc(lessonId).delete();
  }

  // ─── QUESTIONS ─────────────────────────────────────────────────
  @override
  Stream<QuerySnapshot> questionsStream(String catId, String modId, String trailId, String lessonId) =>
      _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).collection(FS.lessons).doc(lessonId).collection(FS.questions).orderBy(FS.order).snapshots();

  @override
  Future<void> createQuestion(String catId, String modId, String trailId, String lessonId, Map<String, dynamic> data) async {
    final doc = _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).collection(FS.lessons).doc(lessonId).collection(FS.questions).doc();
    data[FS.createdAt] = FieldValue.serverTimestamp();
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await doc.set(data);
  }

  @override
  Future<void> updateQuestion(String catId, String modId, String trailId, String lessonId, String qId, Map<String, dynamic> data) async {
    data[FS.updatedAt] = FieldValue.serverTimestamp();
    await _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).collection(FS.lessons).doc(lessonId).collection(FS.questions).doc(qId).update(data);
  }

  @override
  Future<void> deleteQuestion(String catId, String modId, String trailId, String lessonId, String qId) async {
    await _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc(trailId).collection(FS.lessons).doc(lessonId).collection(FS.questions).doc(qId).delete();
  }

  // ─── WIZARD ────────────────────────────────────────────────────
  @override
  Future<void> createTrailWizard({
    required String catId,
    required String modId,
    required int numLessons,
    required int numEvals,
    required int questionsPerLesson,
    required int questionsPerEval,
  }) async {
    final batch = _fs.batch();
    
    // 1. Create Trail
    final trailRef = _fs.collection(FS.categories).doc(catId).collection(FS.modules).doc(modId).collection(FS.trails).doc();
    batch.set(trailRef, {
      FS.title: 'Nova Trilha [WIZARD]',
      FS.categoryId: catId,
      FS.moduleId: modId,
      FS.order: 0,
      'numLessons': numLessons,
      'numEvaluations': numEvals,
      'questionsPerLesson': questionsPerLesson,
      'questionsPerEvaluation': questionsPerEval,
      FS.createdAt: FieldValue.serverTimestamp(),
      FS.updatedAt: FieldValue.serverTimestamp(),
    });

    final lessonsRef = trailRef.collection(FS.lessons);
    int orderIndex = 0;

    // 2. Create Lessons
    for (int i = 1; i <= numLessons; i++) {
      final lessonDoc = lessonsRef.doc();
      batch.set(lessonDoc, {
        FS.title: 'Lição $i',
        FS.type: 'lesson',
        FS.order: orderIndex++,
        FS.createdAt: FieldValue.serverTimestamp(),
        FS.updatedAt: FieldValue.serverTimestamp(),
      });

      final questionsRef = lessonDoc.collection(FS.questions);
      for (int q = 1; q <= questionsPerLesson; q++) {
        final qDoc = questionsRef.doc();
        batch.set(qDoc, {
          FS.statement: 'Questão $q (Lição $i)',
          FS.type: 'multipleChoice',
          FS.options: ['Opção A', 'Opção B', 'Opção C', 'Opção D'],
          FS.correctIndex: 0,
          FS.explanation: '',
          FS.difficulty: 'medium',
          FS.order: q - 1,
          FS.createdAt: FieldValue.serverTimestamp(),
          FS.updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    // 3. Create Evaluations
    for (int i = 1; i <= numEvals; i++) {
      final evalDoc = lessonsRef.doc();
      batch.set(evalDoc, {
        FS.title: 'Avaliação $i',
        FS.type: 'eval',
        FS.order: orderIndex++,
        FS.createdAt: FieldValue.serverTimestamp(),
        FS.updatedAt: FieldValue.serverTimestamp(),
      });

      final questionsRef = evalDoc.collection(FS.questions);
      for (int q = 1; q <= questionsPerEval; q++) {
        final qDoc = questionsRef.doc();
        batch.set(qDoc, {
          FS.statement: 'Questão $q (Avaliação $i)',
          FS.type: 'multipleChoice',
          FS.options: ['Opção A', 'Opção B', 'Opção C', 'Opção D'],
          FS.correctIndex: 0,
          FS.explanation: '',
          FS.difficulty: 'hard',
          FS.order: q - 1,
          FS.createdAt: FieldValue.serverTimestamp(),
          FS.updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }
}