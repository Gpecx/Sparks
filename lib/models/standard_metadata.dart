import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/constants/fs.dart';

/// Metadata for a technical standard stored in Firestore.
/// Collection: standards_metadata/{id}
class StandardMetadata {
  final String id;       // doc ID, ex: 'nr-10'
  final String code;     // display code, ex: 'NR-10'
  final String title;    // short title
  final String description;
  final int clickCount;
  final String colorHex; // ex: '#00C402'

  const StandardMetadata({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.clickCount,
    required this.colorHex,
  });

  factory StandardMetadata.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StandardMetadata(
      id: doc.id,
      code: d['code'] as String? ?? doc.id.toUpperCase(),
      title: d['title'] as String? ?? '',
      description: d[FS.description] as String? ?? '',
      clickCount: (d[FS.clickCount] as num?)?.toInt() ?? 0,
      colorHex: d[FS.colorHex] as String? ?? '#00C402',
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'title': title,
        FS.description: description,
        FS.clickCount: clickCount,
        FS.colorHex: colorHex,
      };
}
