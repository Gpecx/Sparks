import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/models/ebook_model.dart';

final _firestoreProvider = Provider(
  (ref) => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  ),
);

// ── E-books de um módulo ─────────────────────────────────────────
typedef EbookArgs = ({String categoryId, String moduleId});

final ebooksStreamProvider =
    StreamProvider.family<List<EbookModel>, EbookArgs>((ref, args) {
  final firestore = ref.watch(_firestoreProvider);
  return firestore
      .collection(FS.categories)
      .doc(args.categoryId)
      .collection(FS.modules)
      .doc(args.moduleId)
      .collection(FS.ebooks)
      .snapshots()
      .map((snap) => snap.docs.map((d) => EbookModel.fromFirestore(d)).toList());
});

// ── Progresso de leitura do usuário ─────────────────────────────
final ebookProgressStreamProvider =
    StreamProvider<List<EbookProgressModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
      .collection(FS.users)
      .doc(uid)
      .collection(FS.ebookProgress)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => EbookProgressModel.fromFirestore(d)).toList());
});

// ── Progresso de um e-book específico ───────────────────────────
final ebookProgressProvider =
    Provider.family<EbookProgressModel?, String>((ref, ebookId) {
  final allAsync = ref.watch(ebookProgressStreamProvider);
  return allAsync.asData?.value
      .where((p) => p.ebookId == ebookId)
      .firstOrNull;
});

// ── Salvar progresso de leitura ──────────────────────────────────
Future<void> saveEbookProgress({
  required String ebookId,
  required String lastSectionId,
  required bool completed,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final progress = EbookProgressModel(
    ebookId: ebookId,
    lastSectionId: lastSectionId,
    completed: completed,
    completedAt: completed ? DateTime.now() : null,
    lastAccessed: DateTime.now(),
  );
  await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
      .collection(FS.users)
      .doc(uid)
      .collection(FS.ebookProgress)
      .doc(ebookId)
      .set(progress.toFirestore(), SetOptions(merge: true));
}
