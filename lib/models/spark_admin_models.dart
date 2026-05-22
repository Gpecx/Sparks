// ─────────────────────────────────────────────────────────────────
//  SPARK ADMIN MODELS — Complementar aos models existentes
//  Arquivo: lib/models/spark_admin_models.dart
// ─────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────
//  CATEGORIA
// ─────────────────────────────────────────────────────────────────

class SPARKCategory {
  final String id;
  final String title;
  final String subtitle;
  final String? description;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SPARKCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    this.description,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'order': order,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory SPARKCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SPARKCategory(
      id: doc.id,
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      description: data['description'] as String?,
      order: data['order'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SPARKCategory copyWith({
    String? title,
    String? subtitle,
    String? description,
    int? order,
  }) => SPARKCategory(
    id: id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    description: description ?? this.description,
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────
//  MÓDULO
// ─────────────────────────────────────────────────────────────────

class SPARKModule {
  final String id;
  final String categoryId;
  final String title;
  final String subtitle;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SPARKModule({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.subtitle,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
    'categoryId': categoryId,
    'title': title,
    'subtitle': subtitle,
    'order': order,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory SPARKModule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SPARKModule(
      id: doc.id,
      categoryId: data['categoryId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      order: data['order'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SPARKModule copyWith({
    String? title,
    String? subtitle,
    int? order,
  }) => SPARKModule(
    id: id,
    categoryId: categoryId,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────
//  TRILHA
// ─────────────────────────────────────────────────────────────────

class SPARKTrail {
  final String id;
  final String categoryId;
  final String moduleId;
  final String title;
  final int numLessons;
  final int numEvaluations;
  final int questionsPerLesson;
  final int questionsPerEvaluation;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SPARKTrail({
    required this.id,
    required this.categoryId,
    required this.moduleId,
    required this.title,
    required this.numLessons,
    required this.numEvaluations,
    required this.questionsPerLesson,
    required this.questionsPerEvaluation,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
    'categoryId': categoryId,
    'moduleId': moduleId,
    'title': title,
    'numLessons': numLessons,
    'numEvaluations': numEvaluations,
    'questionsPerLesson': questionsPerLesson,
    'questionsPerEvaluation': questionsPerEvaluation,
    'order': order,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory SPARKTrail.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SPARKTrail(
      id: doc.id,
      categoryId: data['categoryId'] as String? ?? '',
      moduleId: data['moduleId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      numLessons: data['numLessons'] as int? ?? 0,
      numEvaluations: data['numEvaluations'] as int? ?? 0,
      questionsPerLesson: data['questionsPerLesson'] as int? ?? 0,
      questionsPerEvaluation: data['questionsPerEvaluation'] as int? ?? 0,
      order: data['order'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SPARKTrail copyWith({
    String? title,
    int? numLessons,
    int? numEvaluations,
    int? questionsPerLesson,
    int? questionsPerEvaluation,
    int? order,
  }) => SPARKTrail(
    id: id,
    categoryId: categoryId,
    moduleId: moduleId,
    title: title ?? this.title,
    numLessons: numLessons ?? this.numLessons,
    numEvaluations: numEvaluations ?? this.numEvaluations,
    questionsPerLesson: questionsPerLesson ?? this.questionsPerLesson,
    questionsPerEvaluation: questionsPerEvaluation ?? this.questionsPerEvaluation,
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────
//  LIÇÃO
// ─────────────────────────────────────────────────────────────────

class SPARKLesson {
  final String id;
  final String trailId;
  final String title;
  final String subtitle;
  final String content;
  final String type; // 'lesson' | 'eval'
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SPARKLesson({
    required this.id,
    required this.trailId,
    required this.title,
    required this.subtitle,
    this.content = '',
    this.type = 'lesson',
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
    'trailId': trailId,
    'title': title,
    'subtitle': subtitle,
    'content': content,
    'type': type,
    'order': order,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory SPARKLesson.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final trailIdFromPath = doc.reference.parent.parent?.id ?? '';
    return SPARKLesson(
      id: doc.id,
      trailId: data['trailId'] as String? ?? trailIdFromPath,
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      content: data['content'] as String? ?? '',
      type: data['type'] as String? ?? 'lesson',
      order: data['order'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SPARKLesson copyWith({
    String? title,
    String? subtitle,
    String? content,
    String? type,
    int? order,
  }) => SPARKLesson(
    id: id,
    trailId: trailId,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    content: content ?? this.content,
    type: type ?? this.type,
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────
//  QUESTÃO
// ─────────────────────────────────────────────────────────────────

class SPARKQuestion {
  final String id;
  final String lessonId;
  final String type; // 'multipleChoice' | 'trueFalse' | 'fillInTheBlanks'
  final String statement;
  final List<String> options;
  final int correctIndex;
  final bool isTrue;
  final String textWithBlanks;
  final String explanation;
  final int difficulty; // 1-5
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SPARKQuestion({
    required this.id,
    required this.lessonId,
    required this.type,
    required this.statement,
    this.options = const [],
    this.correctIndex = 0,
    this.isTrue = false,
    this.textWithBlanks = '',
    required this.explanation,
    this.difficulty = 1,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
    'lessonId': lessonId,
    'type': type,
    'statement': statement,
    'options': options,
    'correctIndex': correctIndex,
    'isTrue': isTrue,
    'textWithBlanks': textWithBlanks,
    'explanation': explanation,
    'difficulty': difficulty,
    'order': order,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory SPARKQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SPARKQuestion(
      id: doc.id,
      lessonId: data['lessonId'] as String? ?? '',
      type: data['type'] as String? ?? 'multipleChoice',
      statement: data['statement'] as String? ?? '',
      options: List<String>.from(data['options'] as List? ?? []),
      correctIndex: data['correctIndex'] as int? ?? 0,
      isTrue: data['isTrue'] as bool? ?? false,
      textWithBlanks: data['textWithBlanks'] as String? ?? '',
      explanation: data['explanation'] as String? ?? '',
      difficulty: data['difficulty'] as int? ?? 1,
      order: data['order'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SPARKQuestion copyWith({
    String? type,
    String? statement,
    List<String>? options,
    int? correctIndex,
    bool? isTrue,
    String? textWithBlanks,
    String? explanation,
    int? difficulty,
    int? order,
  }) => SPARKQuestion(
    id: id,
    lessonId: lessonId,
    type: type ?? this.type,
    statement: statement ?? this.statement,
    options: options ?? this.options,
    correctIndex: correctIndex ?? this.correctIndex,
    isTrue: isTrue ?? this.isTrue,
    textWithBlanks: textWithBlanks ?? this.textWithBlanks,
    explanation: explanation ?? this.explanation,
    difficulty: difficulty ?? this.difficulty,
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
