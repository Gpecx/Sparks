import 'package:spark_app/models/quiz_models.dart';
import 'package:spark_app/data/bloco01_mod01_data.dart';
import 'package:spark_app/data/bloco01_mod02_data.dart';
import 'package:spark_app/data/bloco01_mod03_data.dart';

// ─────────────────────────────────────────────────────────────────
//  REGISTRO CENTRAL DE LIÇÕES
//  Mapeia moduleId (curriculum_models.dart) → List<Lesson>
//  Adicione novos módulos aqui conforme forem criados.
// ─────────────────────────────────────────────────────────────────

final Map<String, List<Lesson>> lessonsRegistry = {
  'mod01_fundamentos': mod01Lessons,
  'mod02_filosofia': mod02Lessons,
  'mod03_linhas': mod03Lessons,
  // mod04 ... mod18 serão adicionados conforme o conteúdo for gerado
};

/// Retorna as lições de um módulo pelo ID.
/// Se não encontrado, retorna lista vazia.
List<Lesson> getLessonsForModule(String moduleId) {
  return lessonsRegistry[moduleId] ?? [];
}
