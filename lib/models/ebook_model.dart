import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────
//  SEÇÃO DO E-BOOK
//  Tipos suportados: text | list | note | formula | summary
// ─────────────────────────────────────────────────────────────────
class EbookSection {
  final String id;
  final String title;
  final String type;
  final String? body;
  final List<String>? items;
  final String? formula;
  final String? explanation;

  const EbookSection({
    required this.id,
    required this.title,
    required this.type,
    this.body,
    this.items,
    this.formula,
    this.explanation,
  });

  factory EbookSection.fromMap(Map<String, dynamic> d) {
    return EbookSection(
      id: d['id'] as String? ?? '',
      title: d['title'] as String? ?? '',
      type: d['type'] as String? ?? 'text',
      body: d['body'] as String?,
      items: d['items'] != null ? List<String>.from(d['items'] as List) : null,
      formula: d['formula'] as String?,
      explanation: d['explanation'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        if (body != null) 'body': body,
        if (items != null) 'items': items,
        if (formula != null) 'formula': formula,
        if (explanation != null) 'explanation': explanation,
      };
}

// ─────────────────────────────────────────────────────────────────
//  CAPÍTULO
//  Firestore: categories/{cat}/modules/{mod}/ebooks/{ebook}/chapters/{chapter}
//  Cada capítulo é um documento próprio, carregado sob demanda.
// ─────────────────────────────────────────────────────────────────
class EbookChapter {
  final String id;
  final int order;
  final String title;
  final String? subtitle;
  final int estimatedMinutes;
  final List<EbookSection> sections;

  const EbookChapter({
    required this.id,
    required this.order,
    required this.title,
    this.subtitle,
    this.estimatedMinutes = 0,
    required this.sections,
  });

  int get sectionCount => sections.length;

  factory EbookChapter.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return EbookChapter(
      id: doc.id,
      order: (d['order'] as num?)?.toInt() ?? 0,
      title: d['title'] as String? ?? '',
      subtitle: d['subtitle'] as String?,
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 0,
      sections: d['sections'] != null
          ? (d['sections'] as List)
              .map((s) => EbookSection.fromMap(s as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  // Para JSON importado (não vem de DocumentSnapshot)
  factory EbookChapter.fromMap(Map<String, dynamic> d) {
    return EbookChapter(
      id: d['id'] as String? ?? '',
      order: (d['order'] as num?)?.toInt() ?? 0,
      title: d['title'] as String? ?? '',
      subtitle: d['subtitle'] as String?,
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 0,
      sections: d['sections'] != null
          ? (d['sections'] as List)
              .map((s) => EbookSection.fromMap(s as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'order': order,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        'estimatedMinutes': estimatedMinutes,
        'sections': sections.map((s) => s.toMap()).toList(),
      };
}

// Item leve do índice de capítulos (vive no documento do e-book).
class EbookChapterRef {
  final String id;
  final int order;
  final String title;
  final int sectionCount;
  final int estimatedMinutes;

  const EbookChapterRef({
    required this.id,
    required this.order,
    required this.title,
    this.sectionCount = 0,
    this.estimatedMinutes = 0,
  });

  factory EbookChapterRef.fromMap(Map<String, dynamic> d) {
    return EbookChapterRef(
      id: d['id'] as String? ?? '',
      order: (d['order'] as num?)?.toInt() ?? 0,
      title: d['title'] as String? ?? '',
      sectionCount: (d['sectionCount'] as num?)?.toInt() ?? 0,
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'order': order,
        'title': title,
        'sectionCount': sectionCount,
        'estimatedMinutes': estimatedMinutes,
      };
}

// ─────────────────────────────────────────────────────────────────
//  E-BOOK
//  Firestore: categories/{catId}/modules/{modId}/ebooks/{ebookId}
//  O documento guarda metadados + índice de capítulos (chapterIndex).
//  As seções vivem nos documentos de capítulo (subcoleção chapters).
// ─────────────────────────────────────────────────────────────────
class EbookModel {
  final String id;
  final String categoryId;
  final String moduleId;
  final String title;
  final String subtitle;
  final int estimatedMinutes;
  final List<String> trailIds;
  final List<EbookChapterRef> chapterIndex;
  final DateTime updatedAt;

  const EbookModel({
    required this.id,
    required this.categoryId,
    required this.moduleId,
    required this.title,
    required this.subtitle,
    required this.estimatedMinutes,
    required this.trailIds,
    required this.chapterIndex,
    required this.updatedAt,
  });

  int get chapterCount => chapterIndex.length;

  factory EbookModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return EbookModel(
      id: doc.id,
      categoryId: d['categoryId'] as String? ?? '',
      moduleId: d['moduleId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      subtitle: d['subtitle'] as String? ?? '',
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 15,
      trailIds: d['trailIds'] != null
          ? List<String>.from(d['trailIds'] as List)
          : const [],
      chapterIndex: d['chapterIndex'] != null
          ? (d['chapterIndex'] as List)
              .map((c) => EbookChapterRef.fromMap(c as Map<String, dynamic>))
              .toList()
          : const [],
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'categoryId': categoryId,
        'moduleId': moduleId,
        'title': title,
        'subtitle': subtitle,
        'estimatedMinutes': estimatedMinutes,
        'trailIds': trailIds,
        'chapterIndex': chapterIndex.map((c) => c.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

// ─────────────────────────────────────────────────────────────────
//  PROGRESSO DE LEITURA
//  Firestore: users/{uid}/ebook_progress/{ebookId}
// ─────────────────────────────────────────────────────────────────
class EbookProgressModel {
  final String ebookId;
  final String lastChapterId;
  final String lastSectionId;
  final List<String> completedChapters;
  final bool completed;
  final DateTime? completedAt;
  final DateTime lastAccessed;

  const EbookProgressModel({
    required this.ebookId,
    required this.lastChapterId,
    required this.lastSectionId,
    this.completedChapters = const [],
    required this.completed,
    this.completedAt,
    required this.lastAccessed,
  });

  factory EbookProgressModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return EbookProgressModel(
      ebookId: doc.id,
      lastChapterId: d['lastChapterId'] as String? ?? '',
      lastSectionId: d['lastSectionId'] as String? ?? '',
      completedChapters: d['completedChapters'] != null
          ? List<String>.from(d['completedChapters'] as List)
          : const [],
      completed: d['completed'] as bool? ?? false,
      completedAt: d['completedAt'] != null
          ? (d['completedAt'] as Timestamp).toDate()
          : null,
      lastAccessed: d['lastAccessed'] != null
          ? (d['lastAccessed'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'lastChapterId': lastChapterId,
        'lastSectionId': lastSectionId,
        'completedChapters': completedChapters,
        'completed': completed,
        if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
        'lastAccessed': Timestamp.fromDate(lastAccessed),
      };
}
