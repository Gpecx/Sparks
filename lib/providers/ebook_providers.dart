import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/models/ebook_model.dart';
import 'package:spark_app/providers/language_provider.dart';

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
  final lang = ref.watch(languageProvider).languageCode; // re-emite ao trocar idioma
  return firestore
      .collection(FS.categories)
      .doc(args.categoryId)
      .collection(FS.modules)
      .doc(args.moduleId)
      .collection(FS.ebooks)
      .snapshots()
      .map((snap) {
        return snap.docs.map((d) => EbookModel.fromFirestore(d, lang: lang)).toList();
      });
});

// ── Capítulos de um e-book (carregados sob demanda) ──────────────
typedef ChapterArgs = ({String categoryId, String moduleId, String ebookId});

final ebookChaptersStreamProvider =
    StreamProvider.family<List<EbookChapter>, ChapterArgs>((ref, args) {
  final firestore = ref.watch(_firestoreProvider);
  final lang = ref.watch(languageProvider).languageCode; // re-emite ao trocar idioma
  return firestore
      .collection(FS.categories)
      .doc(args.categoryId)
      .collection(FS.modules)
      .doc(args.moduleId)
      .collection(FS.ebooks)
      .doc(args.ebookId)
      .collection(FS.chapters)
      .snapshots()
      .map((snap) {
        final list =
            snap.docs.map((d) => EbookChapter.fromFirestore(d, lang: lang)).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });
});

// ── Um capítulo específico (lazy — busca pontual) ────────────────
typedef SingleChapterArgs = ({
  String categoryId,
  String moduleId,
  String ebookId,
  String chapterId
});

final ebookChapterProvider =
    FutureProvider.family<EbookChapter?, SingleChapterArgs>((ref, args) async {
  final firestore = ref.watch(_firestoreProvider);
  final doc = await firestore
      .collection(FS.categories)
      .doc(args.categoryId)
      .collection(FS.modules)
      .doc(args.moduleId)
      .collection(FS.ebooks)
      .doc(args.ebookId)
      .collection(FS.chapters)
      .doc(args.chapterId)
      .get();
  if (!doc.exists) return null;
  final lang = ref.watch(languageProvider).languageCode;
  return EbookChapter.fromFirestore(doc, lang: lang);
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

final ebookProgressProvider =
    Provider.family<EbookProgressModel?, String>((ref, ebookId) {
  final allAsync = ref.watch(ebookProgressStreamProvider);
  return allAsync.asData?.value.where((p) => p.ebookId == ebookId).firstOrNull;
});

// ── Salvar progresso de leitura ──────────────────────────────────
Future<void> saveEbookProgress({
  required String ebookId,
  required String lastChapterId,
  required String lastSectionId,
  required List<String> completedChapters,
  required bool completed,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final progress = EbookProgressModel(
    ebookId: ebookId,
    lastChapterId: lastChapterId,
    lastSectionId: lastSectionId,
    completedChapters: completedChapters,
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
