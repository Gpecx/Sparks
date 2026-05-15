import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      errorMessage: errorMessage,
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
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

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
    state = state.copyWith(errorMessage: null);
  }

  // ─── STREAMS ───────────────────────────────────────────────────
  Stream<QuerySnapshot> streamFor(AdminEntity entity) {
    switch (entity) {
      case AdminEntity.categories:
        return _fs.collection(FS.categories).orderBy(FS.order).snapshots();
      
      case AdminEntity.modules:
        if (state.selectedCategoryId == null) return Stream.empty();
        return _fs
            .collection(FS.categories)
            .doc(state.selectedCategoryId!)
            .collection(FS.modules)
            .orderBy(FS.order)
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
            .orderBy(FS.order)
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
            .orderBy(FS.order)
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
            .orderBy(FS.order)
            .snapshots();
    }
  }

  // ─── CREATE ────────────────────────────────────────────────────
  Future<String> create(AdminEntity entity, Map<String, dynamic> data) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      switch (entity) {
        case AdminEntity.categories:
          final doc = _fs.collection(FS.categories).doc();
          data[FS.order] = 0;
          data[FS.createdAt] = FieldValue.serverTimestamp();
          data[FS.updatedAt] = FieldValue.serverTimestamp();
          doc.set(data).catchError((e) => debugPrint('Erro background: $e'));
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
          doc.set(data).catchError((e) => debugPrint('Erro background: $e'));
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
          doc.set(data).catchError((e) => debugPrint('Erro background: $e'));
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
          doc.set(data).catchError((e) => debugPrint('Erro background: $e'));
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
          doc.set(data).catchError((e) => debugPrint('Erro background: $e'));
          state = state.copyWith(isLoading: false);
          return doc.id;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao criar: $e',
      );
      throw e;
    }
  }

  // ─── UPDATE ────────────────────────────────────────────────────
  Future<bool> update(
    AdminEntity entity,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      data[FS.updatedAt] = FieldValue.serverTimestamp();

      switch (entity) {
        case AdminEntity.categories:
          _fs.collection(FS.categories).doc(docId).update(data)
             .catchError((e) => debugPrint('Erro background: $e'));
          break;

        case AdminEntity.modules:
          if (state.selectedCategoryId == null) throw 'Selecione uma categoria';
          _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(docId)
              .update(data)
              .catchError((e) => debugPrint('Erro background: $e'));
          break;

        case AdminEntity.trails:
          if (state.selectedCategoryId == null || state.selectedModuleId == null) {
            throw 'Selecione categoria e módulo';
          }
          _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(docId)
              .update(data)
              .catchError((e) => debugPrint('Erro background: $e'));
          break;

        case AdminEntity.lessons:
          if (state.selectedCategoryId == null ||
              state.selectedModuleId == null ||
              state.selectedTrailId == null) {
            throw 'Selecione categoria, módulo e trilha';
          }
          _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(state.selectedTrailId!)
              .collection(FS.lessons)
              .doc(docId)
              .update(data)
              .catchError((e) => debugPrint('Erro background: $e'));
          break;

        case AdminEntity.questions:
          if (state.selectedCategoryId == null ||
              state.selectedModuleId == null ||
              state.selectedTrailId == null ||
              state.selectedLessonId == null) {
            throw 'Selecione categoria, módulo, trilha e lição';
          }
          _fs
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
              .update(data)
              .catchError((e) => debugPrint('Erro background: $e'));
          break;
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao atualizar: $e',
      );
      return false;
    }
  }

  // ─── DELETE ────────────────────────────────────────────────────
  Future<bool> delete(AdminEntity entity, String docId) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      switch (entity) {
        case AdminEntity.categories:
          await _fs.collection(FS.categories).doc(docId).delete();
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
          await _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(docId)
              .delete();
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
          await _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(docId)
              .delete();
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
          await _fs
              .collection(FS.categories)
              .doc(state.selectedCategoryId!)
              .collection(FS.modules)
              .doc(state.selectedModuleId!)
              .collection(FS.trails)
              .doc(state.selectedTrailId!)
              .collection(FS.lessons)
              .doc(docId)
              .delete();
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
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao deletar: $e',
      );
      return false;
    }
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

      batch.commit().catchError((e) => debugPrint('Erro background: $e'));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao gerar trilha: $e',
      );
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
          final q = questionsData[i];
          final qRef = lessonRef.collection(FS.questions).doc();
          
          batch.set(qRef, {
            FS.statement: q['statement'] ?? 'Sem enunciado',
            FS.type: q['type'] == 'true_false' ? 'true_false' : 'multipleChoice',
            FS.options: q['options'] ?? (q['type'] == 'true_false' ? ['Verdadeiro', 'Falso'] : []),
            FS.correctIndex: q['correctIndex'] ?? (q['isTrue'] == false ? 1 : 0),
            FS.explanation: q['explanation'] ?? '',
            FS.difficulty: q['difficulty'] ?? 'medium',
            FS.order: i,
            FS.createdAt: FieldValue.serverTimestamp(),
            FS.updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      state = state.copyWith(isLoading: false);
      
      // Atualiza seleção para mostrar o que foi criado
      state = state.copyWith(
        selectedCategoryId: catRef.id,
        selectedModuleId: modRef.id,
        selectedTrailId: trailRef.id,
        contentTabIndex: 2,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro na importação: $e',
      );
      return false;
    }
  }

  void clearMessage() {
    state = state.copyWith(errorMessage: null);
  }
}

final adminControllerProvider = NotifierProvider<AdminController, AdminState>(() {
  return AdminController();
});