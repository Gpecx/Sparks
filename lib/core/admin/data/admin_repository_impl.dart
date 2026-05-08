import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/admin/domain/admin_repository.dart';
import 'package:spark_app/core/constants/fs.dart';

// ─────────────────────────────────────────────────────────────────
//  ADMIN REPOSITORY IMPL — DATA LAYER (Firestore)
// ─────────────────────────────────────────────────────────────────

class AdminRepositoryImpl implements AdminRepository {
  final _db = FirebaseFirestore.instance;

  // ── CATEGORIES ───────────────────────────────────────────────────
  @override
  Stream<QuerySnapshot> readCategories() =>
      _db.collection(FS.categories).orderBy('order').snapshots();

  @override
  Future<void> createCategory(Map<String, dynamic> data) =>
      _db.collection(FS.categories).add({...data, FS.createdAt: FieldValue.serverTimestamp()});

  @override
  Future<void> updateCategory(String id, Map<String, dynamic> data) =>
      _db.collection(FS.categories).doc(id).update({...data, FS.updatedAt: FieldValue.serverTimestamp()});

  @override
  Future<void> deleteCategory(String id) =>
      _db.collection(FS.categories).doc(id).delete();

  // ── MODULES ──────────────────────────────────────────────────────
  // Usando collectionGroup para ler todos os módulos de todas as categorias
  @override
  Stream<QuerySnapshot> readModules() =>
      _db.collectionGroup(FS.modules).orderBy('order').snapshots();

  @override
  Future<void> createModule(Map<String, dynamic> data) {
    final catId = data[FS.categoryId] as String;
    return _db.collection(FS.categories).doc(catId).collection(FS.modules).add({
      ...data,
      FS.createdAt: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateModule(String id, Map<String, dynamic> data) async {
    // Para atualizar, precisamos encontrar o documento primeiro se não tivermos o path completo
    final snap = await _db.collectionGroup(FS.modules).where(FieldPath.documentId, isEqualTo: id).get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.reference.update({...data, FS.updatedAt: FieldValue.serverTimestamp()});
    }
    throw Exception('Módulo não encontrado');
  }

  @override
  Future<void> deleteModule(String id) async {
    final snap = await _db.collectionGroup(FS.modules).where(FieldPath.documentId, isEqualTo: id).get();
    if (snap.docs.isNotEmpty) return snap.docs.first.reference.delete();
  }

  // ── LESSONS ──────────────────────────────────────────────────────
  @override
  Stream<QuerySnapshot> readLessons() =>
      _db.collectionGroup(FS.lessons).orderBy('order').snapshots();

  @override
  Future<void> createLesson(Map<String, dynamic> data) async {
    final modId = data[FS.moduleId] as String;
    // Busca o módulo para saber a categoria pai
    final modSnap = await _db.collectionGroup(FS.modules).where(FieldPath.documentId, isEqualTo: modId).get();
    if (modSnap.docs.isEmpty) throw Exception('Módulo pai não encontrado');
    
    await modSnap.docs.first.reference.collection(FS.lessons).add({
      ...data,
      FS.createdAt: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateLesson(String id, Map<String, dynamic> data) async {
    final snap = await _db.collectionGroup(FS.lessons).where(FieldPath.documentId, isEqualTo: id).get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.reference.update({...data, FS.updatedAt: FieldValue.serverTimestamp()});
    }
    throw Exception('Lição não encontrada');
  }

  @override
  Future<void> deleteLesson(String id) async {
    final snap = await _db.collectionGroup(FS.lessons).where(FieldPath.documentId, isEqualTo: id).get();
    if (snap.docs.isNotEmpty) return snap.docs.first.reference.delete();
  }

  // ── QUESTIONS ────────────────────────────────────────────────────
  @override
  Stream<QuerySnapshot> readQuestions() =>
      _db.collectionGroup(FS.questions).orderBy('order').snapshots();

  @override
  Future<void> createQuestion(Map<String, dynamic> data) async {
    final lessonId = data['lessonId'] as String;
    final lessonSnap = await _db.collectionGroup(FS.lessons).where(FieldPath.documentId, isEqualTo: lessonId).get();
    if (lessonSnap.docs.isEmpty) throw Exception('Lição pai não encontrada');

    await lessonSnap.docs.first.reference.collection(FS.questions).add({
      ...data,
      FS.createdAt: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateQuestion(String id, Map<String, dynamic> data) async {
    final snap = await _db.collectionGroup(FS.questions).where(FieldPath.documentId, isEqualTo: id).get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.reference.update({...data, FS.updatedAt: FieldValue.serverTimestamp()});
    }
    throw Exception('Questão não encontrada');
  }

  @override
  Future<void> deleteQuestion(String id) async {
    final snap = await _db.collectionGroup(FS.questions).where(FieldPath.documentId, isEqualTo: id).get();
    if (snap.docs.isNotEmpty) return snap.docs.first.reference.delete();
  }
}
