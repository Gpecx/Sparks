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
//  E-BOOK
//  Firestore: categories/{catId}/modules/{modId}/ebooks/{ebookId}
// ─────────────────────────────────────────────────────────────────
class EbookModel {
  final String id;
  final String categoryId;
  final String moduleId;
  final String title;
  final String subtitle;
  final int estimatedMinutes;
  final List<String> trailIds;
  final List<EbookSection> sections;
  final DateTime updatedAt;

  const EbookModel({
    required this.id,
    required this.categoryId,
    required this.moduleId,
    required this.title,
    required this.subtitle,
    required this.estimatedMinutes,
    required this.trailIds,
    required this.sections,
    required this.updatedAt,
  });

  int get sectionCount => sections.length;

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
      sections: d['sections'] != null
          ? (d['sections'] as List)
              .map((s) => EbookSection.fromMap(s as Map<String, dynamic>))
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
        'sections': sections.map((s) => s.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

// ─────────────────────────────────────────────────────────────────
//  PROGRESSO DE LEITURA
//  Firestore: users/{uid}/ebook_progress/{ebookId}
// ─────────────────────────────────────────────────────────────────
class EbookProgressModel {
  final String ebookId;
  final String lastSectionId;
  final bool completed;
  final DateTime? completedAt;
  final DateTime lastAccessed;

  const EbookProgressModel({
    required this.ebookId,
    required this.lastSectionId,
    required this.completed,
    this.completedAt,
    required this.lastAccessed,
  });

  factory EbookProgressModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return EbookProgressModel(
      ebookId: doc.id,
      lastSectionId: d['lastSectionId'] as String? ?? '',
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
        'lastSectionId': lastSectionId,
        'completed': completed,
        if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
        'lastAccessed': Timestamp.fromDate(lastAccessed),
      };
}
