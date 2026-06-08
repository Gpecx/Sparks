import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:spark_app/core/constants/fs.dart';

// ─── ENUMS ─────────────────────────────────────────────────────────
enum AdminEntity {
  categories,
  modules,
  trails,
  lessons,
  questions;

  String get label {
    switch (this) {
      case AdminEntity.categories:
        return 'Categorias';
      case AdminEntity.modules:
        return 'Módulos';
      case AdminEntity.trails:
        return 'Trilhas';
      case AdminEntity.lessons:
        return 'Lições';
      case AdminEntity.questions:
        return 'Questões';
    }
  }
}

// ─── STATE ─────────────────────────────────────────────────────────
class AdminState {
  final bool isLoading;
  final String? errorMessage;
  final int sidebarIndex;
  final int contentTabIndex;
  final String? selectedCategoryId;
  final String? selectedModuleId;
  final String? selectedTrailId;
  final String? selectedLessonId;

  AdminState({
    this.isLoading = false,
    this.errorMessage,
    this.sidebarIndex = 1,
    this.contentTabIndex = 0,
    this.selectedCategoryId,
    this.selectedModuleId,
    this.selectedTrailId,
    this.selectedLessonId,
  });

  AdminState copyWith({
    bool? isLoading,
    // Use clearError: true para limpar explicitamente o errorMessage
    bool clearError = false,
    String? errorMessage,
    int? sidebarIndex,
    int? contentTabIndex,
    String? selectedCategoryId,
    String? selectedModuleId,
    String? selectedTrailId,
    String? selectedLessonId,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sidebarIndex: sidebarIndex ?? this.sidebarIndex,
      contentTabIndex: contentTabIndex ?? this.contentTabIndex,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedModuleId: selectedModuleId ?? this.selectedModuleId,
      selectedTrailId: selectedTrailId ?? this.selectedTrailId,
      selectedLessonId: selectedLessonId ?? this.selectedLessonId,
    );
  }
}

// ─── CONTROLLER ────────────────────────────────────────────────────
class AdminController extends Notifier<AdminState> {
  final FirebaseFirestore _fs = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  @override
  AdminState build() {
    return AdminState();
  }

  // ─── SIDEBAR & NAVIGATION ──────────────────────────────────────
  void setSidebarMenu(int index) {
    state = state.copyWith(sidebarIndex: index);
  }

  void setContentTab(int index) {
    state = state.copyWith(contentTabIndex: index);
  }

  // ─── SELECTION ─────────────────────────────────────────────────
  void selectCategory(String categoryId) {
    state = state.copyWith(
      selectedCategoryId: categoryId,
      contentTabIndex: 1,
      selectedModuleId: null,
      selectedTrailId: null,
    );
  }

  void selectModule(String moduleId) {
    state = state.copyWith(
      selectedModuleId: moduleId,
      contentTabIndex: 2,
      selectedTrailId: null,
    );
  }

  void selectTrail(String trailId) {
    state = state.copyWith(selectedTrailId: trailId);
  }

  void selectLesson(String lessonId) {
    state = state.copyWith(selectedLessonId: lessonId);
  }

  void clearMessages() {
    state = state.copyWith(clearError: true);
  }

  // ─── STREAMS ───────────────────────────────────────────────────
  Stream<QuerySnapshot> streamFor(AdminEntity entity) {
    switch (entity) {
      case AdminEntity.categories:
        return _fs.collection(FS.categories).snapshots();
      
      case AdminEntity.modules:
        if (state.selectedCategoryId == null) return Stream.empty();
        return _fs
            .collection(FS.categories)
            .doc(state.selectedCategoryId!)
            .collection(FS.modules)
            .snapshots();
      
      case AdminEntity.trails:
        if (state.selectedCategoryId == null || state.selectedModuleId == null) {
          return Stream.empty();
        }
        return _fs
            .collection(FS.categories)
            .doc(state.selectedCategoryId!)
            .collection(FS.modules)
            .doc(state.selectedModuleId!)
            .collection(FS.trails)
            .snapshots();
      
      case AdminEntity.lessons:
        if (state.selectedCategoryId == null ||
            state.selectedModuleId == null ||
            state.selectedTrailId == null) {
          return Stream.empty();
        }
        return _fs
            .collection(FS.categories)
            .doc(state.selectedCategoryId!)
            .collection(FS.modules)
            .doc(state.selectedModuleId!)
            .collection(FS.trails)
            .doc(state.selectedTrailId!)
            .collection(FS.lessons)
            .snapshots();
      
      case AdminEntity.questions:
        if (state.selectedCategoryId == null ||
            state.selectedModuleId == null ||
            state.selectedTrailId == null ||
            state.selectedLessonId == null) {
          return Stream.empty();
        }
        return _fs
            .collection(FS.categories)
            .doc(state.selectedCategoryId!)
            .collection(FS.modules)
            .doc(state.selectedModuleId!)
            .collection(FS.trails)
            .doc(state.selectedTrailId!)
            .collection(FS.lessons)
            .doc(state.selectedLessonId!)
            .collection(FS.questions)
            .snapshots();
    }
  }

  // ─── CREATE ────────────────────────────────────────────────────
  Future<String> create(AdminEntity entity, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      switch (entity) {
        case AdminEntity.categories:
          final doc = _fs.collection(FS.categories).doc();
          data[FS.order] = 0;
          data[FS.createdAt] = FieldValue.serverTimestamp();
          data[FS.updatedAt] = FieldValue.serverTimestamp();
          await doc.set(data);
          state = state.copyWith(isLoading: false);
          return doc.id;

        case AdminEntity.modules:
          if (state.selectedCategoryId == null) throw 'Selecione uma categoria';
          final doc = _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc();
          data[FS.categoryId] = state.selectedCategoryId;
          data[FS.order] = 0;
          data[FS.createdAt] = FieldValue.serverTimestamp();
          data[FS.updatedAt] = FieldValue.serverTimestamp();
          await doc.set(data);
          state = state.copyWith(isLoading: false);
          return doc.id;

        case AdminEntity.trails:
          if (state.selectedCategoryId == null || state.selectedModuleId == null) {
            throw 'Selecione categoria e módulo';
          }
          final doc = _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc();
          data[FS.categoryId] = state.selectedCategoryId;
          data[FS.moduleId] = state.selectedModuleId;
          data[FS.order] = 0;
          data[FS.createdAt] = FieldValue.serverTimestamp();
          data[FS.updatedAt] = FieldValue.serverTimestamp();
          await doc.set(data);
          state = state.copyWith(isLoading: false);
          return doc.id;

        case AdminEntity.lessons:
          if (state.selectedCategoryId == null ||
              state.selectedModuleId == null ||
              state.selectedTrailId == null) {
            throw 'Selecione categoria, módulo e trilha';
          }
          final doc = _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(state.selectedTrailId!)
              .collection(FS.lessons)
              .doc();
          data[FS.order] = 0;
          data[FS.createdAt] = FieldValue.serverTimestamp();
          data[FS.updatedAt] = FieldValue.serverTimestamp();
          await doc.set(data);
          state = state.copyWith(isLoading: false);
          return doc.id;

        case AdminEntity.questions:
          if (state.selectedCategoryId == null ||
              state.selectedModuleId == null ||
              state.selectedTrailId == null ||
              state.selectedLessonId == null) {
            throw 'Selecione categoria, módulo, trilha e lição';
          }
          final doc = _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(state.selectedTrailId!)
              .collection(FS.lessons)
              .doc(state.selectedLessonId!)
              .collection(FS.questions)
              .doc();
          data[FS.order] = 0;
          data[FS.createdAt] = FieldValue.serverTimestamp();
          data[FS.updatedAt] = FieldValue.serverTimestamp();
          await doc.set(data);
          state = state.copyWith(isLoading: false);
          return doc.id;
      }
    } on FirebaseException catch (e) {
      final msg = 'Erro Firebase ao criar ${entity.label}: [${e.code}] ${e.message}';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      rethrow;
    } catch (e) {
      final msg = 'Erro ao criar ${entity.label}: $e';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      rethrow;
    }
  }

  // ─── UPDATE ────────────────────────────────────────────────────
  Future<bool> update(
    AdminEntity entity,
    String docId,
    Map<String, dynamic> data,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      data[FS.updatedAt] = FieldValue.serverTimestamp();

      switch (entity) {
        case AdminEntity.categories:
          await _fs.collection(FS.categories).doc(docId).update(data);
          break;

        case AdminEntity.modules:
          if (state.selectedCategoryId == null) throw 'Selecione uma categoria';
          await _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(docId)
              .update(data);
          break;

        case AdminEntity.trails:
          if (state.selectedCategoryId == null || state.selectedModuleId == null) {
            throw 'Selecione categoria e módulo';
          }
          await _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(docId)
              .update(data);
          break;

        case AdminEntity.lessons:
          if (state.selectedCategoryId == null ||
              state.selectedModuleId == null ||
              state.selectedTrailId == null) {
            throw 'Selecione categoria, módulo e trilha';
          }
          await _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(state.selectedTrailId!)
              .collection(FS.lessons)
              .doc(docId)
              .update(data);
          break;

        case AdminEntity.questions:
          if (state.selectedCategoryId == null ||
              state.selectedModuleId == null ||
              state.selectedTrailId == null ||
              state.selectedLessonId == null) {
            throw 'Selecione categoria, módulo, trilha e lição';
          }
          await _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(state.selectedTrailId!)
              .collection(FS.lessons)
              .doc(state.selectedLessonId!)
              .collection(FS.questions)
              .doc(docId)
              .update(data);
          break;
      }

      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseException catch (e) {
      final msg = 'Erro Firebase ao atualizar ${entity.label}: [${e.code}] ${e.message}';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      final msg = 'Erro ao atualizar ${entity.label}: $e';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  // ─── DELETE (com cascata completa) ─────────────────────────────
  Future<bool> delete(AdminEntity entity, String docId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {

      switch (entity) {
        case AdminEntity.categories:
          final catRef = _fs.collection(FS.categories).doc(docId);
          await _deleteCategoryDeep(catRef);
          if (state.selectedCategoryId == docId) {
            state = state.copyWith(
              selectedCategoryId: null,
              selectedModuleId: null,
              selectedTrailId: null,
              selectedLessonId: null,
            );
          }
          break;

        case AdminEntity.modules:
          if (state.selectedCategoryId == null) throw 'Selecione uma categoria';
          final modRef = _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(docId);
          await _deleteModuleDeep(modRef);
          if (state.selectedModuleId == docId) {
            state = state.copyWith(
              selectedModuleId: null,
              selectedTrailId: null,
              selectedLessonId: null,
            );
          }
          break;

        case AdminEntity.trails:
          if (state.selectedCategoryId == null || state.selectedModuleId == null) {
            throw 'Selecione categoria e módulo';
          }
          final trailRef = _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(docId);
          await _deleteTrailDeep(trailRef);
          if (state.selectedTrailId == docId) {
            state = state.copyWith(
              selectedTrailId: null,
              selectedLessonId: null,
            );
          }
          break;

        case AdminEntity.lessons:
          if (state.selectedCategoryId == null ||
              state.selectedModuleId == null ||
              state.selectedTrailId == null) {
            throw 'Selecione categoria, módulo e trilha';
          }
          final lessonRef = _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(state.selectedTrailId!)
              .collection(FS.lessons)
              .doc(docId);
          await _deleteLessonDeep(lessonRef);
          if (state.selectedLessonId == docId) {
            state = state.copyWith(selectedLessonId: null);
          }
          break;

        case AdminEntity.questions:
          if (state.selectedCategoryId == null ||
              state.selectedModuleId == null ||
              state.selectedTrailId == null ||
              state.selectedLessonId == null) {
            throw 'Selecione categoria, módulo, trilha e lição';
          }
          await _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(state.selectedTrailId!)
              .collection(FS.lessons)
              .doc(state.selectedLessonId!)
              .collection(FS.questions)
              .doc(docId)
              .delete();
          break;
      }

      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseException catch (e) {
      final msg = 'Erro Firebase ao deletar ${entity.label}: [${e.code}] ${e.message}';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      final msg = 'Erro ao deletar ${entity.label}: $e';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  // ─── HELPERS DE CASCATA ─────────────────────────────────────────
  // Estratégia: Await explícito para garantir que não haja documentos órfãos 
  // e propagar qualquer erro para a UI.

  Future<void> _deleteCategoryDeep(DocumentReference catRef) async {
    final modules = await catRef.collection(FS.modules).get();
    for (final mod in modules.docs) {
      await _deleteModuleDeep(mod.reference);
    }
    await catRef.delete();
  }

  Future<void> _deleteModuleDeep(DocumentReference modRef) async {
    final trails = await modRef.collection(FS.trails).get();
    for (final trail in trails.docs) {
      await _deleteTrailDeep(trail.reference);
    }
    await modRef.delete();
  }

  Future<void> _deleteTrailDeep(DocumentReference trailRef) async {
    final lessons = await trailRef.collection(FS.lessons).get();
    for (final lesson in lessons.docs) {
      await _deleteLessonDeep(lesson.reference);
    }
    await trailRef.delete();
  }

  Future<void> _deleteLessonDeep(DocumentReference lessonRef) async {
    final questions = await lessonRef.collection(FS.questions).get();
    if (questions.docs.isNotEmpty) {
      final batch = _fs.batch();
      for (final q in questions.docs) {
        batch.delete(q.reference);
      }
      await batch.commit();
    }
    await lessonRef.delete();
  }

  // ─── GENERATE TRAIL ────────────────────────────────────────────
  Future<bool> generateTrail({
    String? categoryId,
    String? moduleId,
    required String title,
    required int numLessons,
    required int numEvaluations,
    required int questionsPerLesson,
    required int questionsPerEvaluation,
    List<String>? lessonNames,
    List<String>? evaluationNames,
  }) async {
    try {
      final targetCategoryId = categoryId ?? state.selectedCategoryId;
      final targetModuleId = moduleId ?? state.selectedModuleId;

      if (targetCategoryId == null || targetModuleId == null) {
        throw 'Selecione categoria e módulo';
      }

      state = state.copyWith(isLoading: true, errorMessage: null);

      // 1. Criar documento da trilha
      final trailRef = _fs
          .collection(FS.categories)
          .doc(targetCategoryId)
          .collection(FS.modules)
          .doc(targetModuleId)
          .collection(FS.trails)
          .doc();

      final batch = _fs.batch();

      // 2. Criar trilha com metadados
      batch.set(trailRef, {
        FS.title: title,
        'numLessons': numLessons,
        'numEvaluations': numEvaluations,
        'questionsPerLesson': questionsPerLesson,
        'questionsPerEvaluation': questionsPerEvaluation,
        FS.categoryId: targetCategoryId,
        FS.moduleId: targetModuleId,
        FS.order: 0,
        FS.createdAt: FieldValue.serverTimestamp(),
        FS.updatedAt: FieldValue.serverTimestamp(),
      });

      int orderCounter = 0;

      // 3. Criar lições
      for (int i = 0; i < numLessons; i++) {
        final lessonName = (lessonNames != null && i < lessonNames.length) 
            ? lessonNames[i] 
            : 'Lição ${i + 1}';
            
        final lessonRef = trailRef.collection(FS.lessons).doc();
        batch.set(lessonRef, {
          FS.title: lessonName,
          FS.type: 'lesson',
          'content': '', // Vazio esperando conteúdo
          FS.order: orderCounter++,
          FS.createdAt: FieldValue.serverTimestamp(),
          FS.updatedAt: FieldValue.serverTimestamp(),
        });

        // 4. Criar questões da lição (se houver)
        for (int q = 1; q <= questionsPerLesson; q++) {
          final qRef = lessonRef.collection(FS.questions).doc();
          batch.set(qRef, {
            FS.statement: 'Questão $q ($lessonName)',
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

      // 5. Criar avaliações
      for (int i = 0; i < numEvaluations; i++) {
        final evalName = (evaluationNames != null && i < evaluationNames.length)
            ? evaluationNames[i]
            : 'Avaliação ${i + 1}';

        final evalRef = trailRef.collection(FS.lessons).doc();
        batch.set(evalRef, {
          FS.title: evalName,
          FS.type: 'eval',
          'content': 'Avaliação de conhecimentos.',
          FS.order: orderCounter++,
          FS.createdAt: FieldValue.serverTimestamp(),
          FS.updatedAt: FieldValue.serverTimestamp(),
        });

        // 6. Criar questões da avaliação
        for (int q = 1; q <= questionsPerEvaluation; q++) {
          final qRef = evalRef.collection(FS.questions).doc();
          batch.set(qRef, {
            FS.statement: 'Questão $q ($evalName)',
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
      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseException catch (e) {
      final msg = 'Erro Firebase ao gerar trilha: [${e.code}] ${e.message}';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      final msg = 'Erro ao gerar trilha: $e';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  // ─── IMPORT FROM JSON ──────────────────────────────────────────
  Future<bool> importFromJSON(Map<String, dynamic> json) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      
      final categoryTitle = json['category'] as String?;
      final moduleTitle = json['module'] as String?;
      final trailTitle = json['trail'] ?? json['lesson'] as String?; // Usa lesson como trail se não houver trail
      final questionsData = json['questions'] as List?;

      if (categoryTitle == null || moduleTitle == null || trailTitle == null) {
        throw 'JSON inválido: Campos category, module e trail/lesson são obrigatórios';
      }

      final batch = _fs.batch();

      // 1. Buscar ou criar Categoria
      final catQuery = await _fs.collection(FS.categories)
          .where(FS.title, isEqualTo: categoryTitle)
          .limit(1)
          .get();
      
      DocumentReference catRef;
      if (catQuery.docs.isEmpty) {
        catRef = _fs.collection(FS.categories).doc();
        batch.set(catRef, {
          FS.title: categoryTitle,
          'subtitle': 'Importado via JSON',
          'description': 'Importado via JSON',
          FS.order: 0,
          FS.createdAt: FieldValue.serverTimestamp(),
          FS.updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        catRef = catQuery.docs.first.reference;
      }

      // 2. Buscar ou criar Módulo
      final modQuery = await catRef.collection(FS.modules)
          .where(FS.title, isEqualTo: moduleTitle)
          .limit(1)
          .get();

      DocumentReference modRef;
      if (modQuery.docs.isEmpty) {
        modRef = catRef.collection(FS.modules).doc();
        batch.set(modRef, {
          FS.title: moduleTitle,
          'subtitle': 'Importado via JSON',
          FS.categoryId: catRef.id,
          FS.order: 0,
          FS.createdAt: FieldValue.serverTimestamp(),
          FS.updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        modRef = modQuery.docs.first.reference;
      }

      // 3. Criar Trilha
      final trailRef = modRef.collection(FS.trails).doc();
      batch.set(trailRef, {
        FS.title: trailTitle,
        'numLessons': 1,
        'numEvaluations': 0,
        FS.categoryId: catRef.id,
        FS.moduleId: modRef.id,
        FS.order: 0,
        FS.createdAt: FieldValue.serverTimestamp(),
        FS.updatedAt: FieldValue.serverTimestamp(),
      });

      // 4. Criar Lição
      final lessonRef = trailRef.collection(FS.lessons).doc();
      batch.set(lessonRef, {
        FS.title: trailTitle,
        FS.type: 'lesson',
        'content': 'Conteúdo importado via JSON.',
        FS.order: 0,
        FS.createdAt: FieldValue.serverTimestamp(),
        FS.updatedAt: FieldValue.serverTimestamp(),
      });

      // 5. Adicionar Questões
      if (questionsData != null) {
        for (int i = 0; i < questionsData.length; i++) {
          final q = questionsData[i] as Map<String, dynamic>;
          final qRef = lessonRef.collection(FS.questions).doc();

          // Normaliza o tipo do JSON para camelCase usado no Firestore
          final rawType = q['type'] as String? ?? 'multiple_choice';
          final String firestoreType;
          switch (rawType) {
            case 'true_false':
            case 'trueFalse':
              firestoreType = 'trueFalse';
              break;
            case 'fill_blank':
            case 'fill_in_the_blanks':
            case 'fillInTheBlanks':
              // Converte para multipleChoice diretamente
              firestoreType = 'multipleChoice';
              break;
            default:
              firestoreType = 'multipleChoice';
          }

          final Map<String, dynamic> qData = {
            FS.statement: q['statement'] ?? 'Sem enunciado',
            FS.type: firestoreType,
            FS.explanation: q['explanation'] ?? '',
            FS.difficulty: q['difficulty'] ?? 'medium',
            FS.order: i,
            FS.createdAt: FieldValue.serverTimestamp(),
            FS.updatedAt: FieldValue.serverTimestamp(),
          };

          if (firestoreType == 'multipleChoice') {
            qData[FS.options] = List<String>.from(q['options'] as List? ?? []);
            qData[FS.correctIndex] = q['correctIndex'] ?? 0;
          } else if (firestoreType == 'trueFalse') {
            // Suporta 'isTrue' (bool) ou 'correctIndex' (0=V / 1=F)
            final bool resolvedIsTrue;
            if (q['isTrue'] != null) {
              resolvedIsTrue = q['isTrue'] as bool;
            } else if (q['correctIndex'] != null) {
              resolvedIsTrue = (q['correctIndex'] as num).toInt() == 0;
            } else {
              resolvedIsTrue = true;
            }
            qData[FS.isTrue] = resolvedIsTrue;
            qData[FS.correctIndex] = resolvedIsTrue ? 0 : 1;
          } else if (firestoreType == 'multipleChoice' && (q['type'] == 'fill_blank' || q['type'] == 'fill_in_the_blanks' || q['type'] == 'fillInTheBlanks')) {
            // fill_blank convertido para multipleChoice:
            // options já existem no JSON; caso não existam, usa answer + fallback
            final rawOptions = q['options'] as List?;
            final rawAnswer = q['answer'] as String?;
            List<String> opts;
            int correctIdx = 0;
            if (rawOptions != null && rawOptions.isNotEmpty) {
              opts = List<String>.from(rawOptions);
              correctIdx = rawAnswer != null ? opts.indexOf(rawAnswer) : 0;
              if (correctIdx < 0) correctIdx = 0;
            } else if (rawAnswer != null) {
              const fallback = ['Nenhuma das anteriores', 'Incorreto', 'Não se aplica', 'Outra opção'];
              final distractors = <String>[];
              for (final f in fallback) {
                if (f != rawAnswer) {
                  distractors.add(f);
                  if (distractors.length >= 3) break;
                }
              }
              opts = [rawAnswer, ...distractors];
              opts.shuffle();
              correctIdx = opts.indexOf(rawAnswer);
            } else {
              opts = ['Opção A', 'Opção B', 'Opção C', 'Opção D'];
            }
            qData[FS.options] = opts;
            qData[FS.correctIndex] = correctIdx;
          }

          batch.set(qRef, qData);
        }
      }

      await batch.commit();
      state = state.copyWith(isLoading: false);
      
      // Guarda os IDs para navegação após fechar o dialog
      _pendingCategoryId = catRef.id;
      _pendingModuleId   = modRef.id;

      return true;
    } on FirebaseException catch (e) {
      final msg = 'Erro Firebase na importação: [${e.code}] ${e.message}';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      final msg = 'Erro na importação: $e';
      debugPrint(msg);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  // Navegação pós-importão (chamar depois de fechar o dialog)
  String? _pendingCategoryId;
  String? _pendingModuleId;

  void applyPendingNavigation() {
    if (_pendingCategoryId != null && _pendingModuleId != null) {
      state = state.copyWith(
        sidebarIndex: 1,
        selectedCategoryId: _pendingCategoryId,
        selectedModuleId: _pendingModuleId,
        contentTabIndex: 2,
      );
      _pendingCategoryId = null;
      _pendingModuleId   = null;
    }
  }

  // clearMessage é alias de clearMessages — mantido por compatibilidade
  void clearMessage() => clearMessages();
}

final adminControllerProvider = NotifierProvider<AdminController, AdminState>(() {
  return AdminController();
});