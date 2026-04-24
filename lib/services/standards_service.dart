import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/models/standard_metadata.dart';

/// Manages Firestore metadata for Technical Standards.
///
/// Responsibilities:
///  - Track clicks per standard (clickCount via FieldValue.increment)
///  - Stream top-N standards ordered by clickCount
///  - Bootstrap the standards_metadata collection on first run
class StandardsService {
  static final StandardsService _instance = StandardsService._internal();
  factory StandardsService() => _instance;
  StandardsService._internal();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FS.standardsMetadata);

  // ── Default catalog seeded into Firestore on first run ─────────
  static const List<Map<String, dynamic>> _defaults = [
    {'id': 'nr-10', 'code': 'NR-10', 'title': 'Eletricidade', 'description': 'Segurança em Instalações e Serviços em Eletricidade', 'colorHex': '#00C402', 'clickCount': 0},
    {'id': 'nr-12', 'code': 'NR-12', 'title': 'Máquinas', 'description': 'Segurança no Trabalho em Máquinas e Equipamentos', 'colorHex': '#1D5F31', 'clickCount': 0},
    {'id': 'nr-18', 'code': 'NR-18', 'title': 'Construção', 'description': 'Segurança e Saúde no Trabalho na Construção', 'colorHex': '#00C402', 'clickCount': 0},
    {'id': 'nr-23', 'code': 'NR-23', 'title': 'Incêndios', 'description': 'Proteção Contra Incêndios', 'colorHex': '#E57373', 'clickCount': 0},
    {'id': 'nr-33', 'code': 'NR-33', 'title': 'Espaço Confinado', 'description': 'Segurança nos Trabalhos em Espaço Confinado', 'colorHex': '#B0BEC5', 'clickCount': 0},
    {'id': 'nr-35', 'code': 'NR-35', 'title': 'Trabalho em Altura', 'description': 'Trabalho em Altura e Prevenção de Quedas', 'colorHex': '#FFB300', 'clickCount': 0},
    {'id': 'tc-05', 'code': 'TC-05', 'title': 'Prevenção de Quedas', 'description': 'Trabalho em Altura e Prevenção de Quedas', 'colorHex': '#FF9800', 'clickCount': 0},
    {'id': 'tc-08', 'code': 'TC-08', 'title': 'Soldagem', 'description': 'Controle de Qualidade em Soldagem', 'colorHex': '#78909C', 'clickCount': 0},
    {'id': 'tp-12', 'code': 'TP-12', 'title': 'Máquinas Pesadas', 'description': 'Operação de Máquinas Pesadas', 'colorHex': '#42A5F5', 'clickCount': 0},
    {'id': 'tp-15', 'code': 'TP-15', 'title': 'Emergência Industrial', 'description': 'Procedimentos de Emergência Industrial', 'colorHex': '#AB47BC', 'clickCount': 0},
  ];

  bool _initialized = false;

  /// Creates standards_metadata documents in a single batch if they don't exist.
  Future<void> initializeStandards() async {
    if (_initialized) return;
    _initialized = true;

    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return; // already seeded

    final batch = _db.batch();
    for (final s in _defaults) {
      final ref = _col.doc(s['id'] as String);
      // Use Map without the 'id' key (stored as doc ID)
      final data = Map<String, dynamic>.from(s)..remove('id');
      batch.set(ref, data, SetOptions(merge: false));
    }
    await batch.commit();
  }

  /// Increments the click counter for a given standard.
  /// Uses FieldValue.increment to avoid read-modify-write.
  Future<void> incrementClick(String standardId) async {
    await _col.doc(standardId).update({
      FS.clickCount: FieldValue.increment(1),
    });
  }

  /// Streams the top [limit] standards ordered by clickCount descending.
  Stream<List<StandardMetadata>> getTopStandards({int limit = 3}) {
    return _col
        .orderBy(FS.clickCount, descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => StandardMetadata.fromFirestore(d)).toList());
  }

  /// One-shot fetch of a single standard by its document ID.
  Future<StandardMetadata?> getStandard(String standardId) async {
    final doc = await _col.doc(standardId).get();
    if (!doc.exists) return null;
    return StandardMetadata.fromFirestore(doc);
  }
}
