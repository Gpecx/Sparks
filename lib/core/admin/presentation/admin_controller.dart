import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/admin/data/admin_repository_impl.dart';
import 'package:spark_app/core/admin/domain/admin_repository.dart';

// ─────────────────────────────────────────────────────────────────
//  ADMIN ENTITY ENUM — tipagem das 4 entidades gerenciáveis
// ─────────────────────────────────────────────────────────────────

enum AdminEntity { categories, modules, lessons, questions }

extension AdminEntityX on AdminEntity {
  String get label => switch (this) {
        AdminEntity.categories => 'Categorias',
        AdminEntity.modules    => 'Módulos',
        AdminEntity.lessons    => 'Trilhas/Lições',
        AdminEntity.questions  => 'Questões',
      };
}

// ─────────────────────────────────────────────────────────────────
//  STATE
// ─────────────────────────────────────────────────────────────────

class AdminState {
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const AdminState({
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  AdminState copyWith({bool? isSaving, String? errorMessage, String? successMessage}) =>
      AdminState(
        isSaving: isSaving ?? this.isSaving,
        errorMessage: errorMessage,
        successMessage: successMessage,
      );
}

// ─────────────────────────────────────────────────────────────────
//  NOTIFIER
// ─────────────────────────────────────────────────────────────────

class AdminController extends Notifier<AdminState> {
  late final AdminRepository _repo;

  @override
  AdminState build() {
    _repo = AdminRepositoryImpl();
    return const AdminState();
  }

  // ── Streams ──────────────────────────────────────────────────────
  Stream<QuerySnapshot> streamFor(AdminEntity entity) => switch (entity) {
        AdminEntity.categories => _repo.readCategories(),
        AdminEntity.modules    => _repo.readModules(),
        AdminEntity.lessons    => _repo.readLessons(),
        AdminEntity.questions  => _repo.readQuestions(),
      };

  // ── DATA PROCESSING ──────────────────────────────────────────────
  Map<String, dynamic> _processData(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    
    // Converte 'order' para int
    if (data.containsKey('order')) {
      data['order'] = int.tryParse(data['order'].toString()) ?? 0;
    }
    
    // Converte 'correctIndex' para int
    if (data.containsKey('correctIndex')) {
      data['correctIndex'] = int.tryParse(data['correctIndex'].toString()) ?? 0;
    }

    // Converte 'options' de String (A|B|C) para List<String>
    if (data.containsKey('options') && data['options'] is String) {
      final str = data['options'] as String;
      if (str.isNotEmpty) {
        data['options'] = str.split('|').map((e) => e.trim()).toList();
      } else {
        data['options'] = <String>[];
      }
    }

    return data;
  }

  // ── CREATE ───────────────────────────────────────────────────────
  Future<void> create(AdminEntity entity, Map<String, dynamic> rawData) async {
    state = state.copyWith(isSaving: true);
    final data = _processData(rawData);
    try {
      await switch (entity) {
        AdminEntity.categories => _repo.createCategory(data),
        AdminEntity.modules    => _repo.createModule(data),
        AdminEntity.lessons    => _repo.createLesson(data),
        AdminEntity.questions  => _repo.createQuestion(data),
      };
      state = state.copyWith(isSaving: false, successMessage: '${entity.label} criado com sucesso!');
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Erro ao criar: $e');
    }
  }

  // ── UPDATE ───────────────────────────────────────────────────────
  Future<void> update(AdminEntity entity, String id, Map<String, dynamic> rawData) async {
    state = state.copyWith(isSaving: true);
    final data = _processData(rawData);
    try {
      await switch (entity) {
        AdminEntity.categories => _repo.updateCategory(id, data),
        AdminEntity.modules    => _repo.updateModule(id, data),
        AdminEntity.lessons    => _repo.updateLesson(id, data),
        AdminEntity.questions  => _repo.updateQuestion(id, data),
      };
      state = state.copyWith(isSaving: false, successMessage: '${entity.label} atualizado!');
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Erro ao atualizar: $e');
    }
  }

  // ── DELETE ───────────────────────────────────────────────────────
  Future<void> delete(AdminEntity entity, String id) async {
    try {
      await switch (entity) {
        AdminEntity.categories => _repo.deleteCategory(id),
        AdminEntity.modules    => _repo.deleteModule(id),
        AdminEntity.lessons    => _repo.deleteLesson(id),
        AdminEntity.questions  => _repo.deleteQuestion(id),
      };
      state = state.copyWith(successMessage: '${entity.label} removido.');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao deletar: $e');
    }
  }

  void clearMessages() => state = state.copyWith();
}

// ─────────────────────────────────────────────────────────────────
//  PROVIDERS
// ─────────────────────────────────────────────────────────────────

final adminControllerProvider = NotifierProvider<AdminController, AdminState>(
  AdminController.new,
);
