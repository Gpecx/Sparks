import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────
//  ADMIN REPOSITORY — DOMAIN LAYER (Abstract)
//
//  O impl usa collectionGroup para ler/atualizar/deletar sem
//  precisar dos IDs de pais. O categoryId/moduleId fica DENTRO
//  do próprio documento (campo de dados).
// ─────────────────────────────────────────────────────────────────

abstract class AdminRepository {
  // ── CATEGORIES ────────────────────────────────────────────────────
  Stream<QuerySnapshot> readCategories();
  Future<void> createCategory(Map<String, dynamic> data);
  Future<void> updateCategory(String id, Map<String, dynamic> data);
  Future<void> deleteCategory(String id);

  // ── MODULES ───────────────────────────────────────────────────────
  Stream<QuerySnapshot> readModules();
  Future<void> createModule(Map<String, dynamic> data);
  Future<void> updateModule(String id, Map<String, dynamic> data);
  Future<void> deleteModule(String id);

  // ── LESSONS ───────────────────────────────────────────────────────
  Stream<QuerySnapshot> readLessons();
  Future<void> createLesson(Map<String, dynamic> data);
  Future<void> updateLesson(String id, Map<String, dynamic> data);
  Future<void> deleteLesson(String id);

  // ── QUESTIONS ─────────────────────────────────────────────────────
  Stream<QuerySnapshot> readQuestions();
  Future<void> createQuestion(Map<String, dynamic> data);
  Future<void> updateQuestion(String id, Map<String, dynamic> data);
  Future<void> deleteQuestion(String id);
}
