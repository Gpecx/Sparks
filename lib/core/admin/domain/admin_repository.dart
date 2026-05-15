import 'package:cloud_firestore/cloud_firestore.dart';

abstract class AdminRepository {
  // Categorias
  Stream<QuerySnapshot> categoriesStream();
  Future<void> createCategory(Map<String, dynamic> data);
  Future<void> updateCategory(String catId, Map<String, dynamic> data);
  Future<void> deleteCategory(String catId);

  // Módulos
  Stream<QuerySnapshot> modulesStream(String catId);
  Future<void> createModule(String catId, Map<String, dynamic> data);
  Future<void> updateModule(String catId, String modId, Map<String, dynamic> data);
  Future<void> deleteModule(String catId, String modId);

  // Trilhas, Lições e Questões podem ser adicionadas conforme necessário
  Stream<QuerySnapshot> trailsStream(String catId, String modId);
  Future<void> createTrail(String catId, String modId, Map<String, dynamic> data);
  Future<void> updateTrail(String catId, String modId, String trailId, Map<String, dynamic> data);
  Future<void> deleteTrail(String catId, String modId, String trailId);

  Stream<QuerySnapshot> lessonsStream(String catId, String modId, String trailId);
  Future<void> createLesson(String catId, String modId, String trailId, Map<String, dynamic> data);
  Future<void> updateLesson(String catId, String modId, String trailId, String lessonId, Map<String, dynamic> data);
  Future<void> deleteLesson(String catId, String modId, String trailId, String lessonId);

  Stream<QuerySnapshot> questionsStream(String catId, String modId, String trailId, String lessonId);
  Future<void> createQuestion(String catId, String modId, String trailId, String lessonId, Map<String, dynamic> data);
  Future<void> updateQuestion(String catId, String modId, String trailId, String lessonId, String qId, Map<String, dynamic> data);
  Future<void> deleteQuestion(String catId, String modId, String trailId, String lessonId, String qId);

  // Wizard
  Future<void> createTrailWizard({
    required String catId,
    required String modId,
    required int numLessons,
    required int numEvals,
    required int questionsPerLesson,
    required int questionsPerEval,
  });
}