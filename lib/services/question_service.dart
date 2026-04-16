import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/fs.dart';

class QuestionService {
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;
  QuestionService._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  Future<void> addQuestions(String catId, String modId, String lessonId, List<Map<String, dynamic>> qs) async {
    final batch = _fs.batch();
    final colRef = _fs
        .collection(FS.categories)
        .doc(catId)
        .collection(FS.modules)
        .doc(modId)
        .collection(FS.lessons)
        .doc(lessonId)
        .collection(FS.questions);

    for (var i = 0; i < qs.length; i += 450) {
      final currentBatch = _fs.batch();
      final chunk = qs.skip(i).take(450);
      for (final q in chunk) {
        final docRef = colRef.doc(q['id'] as String);
        currentBatch.set(docRef, q);
      }
      await currentBatch.commit();
    }
  }

  Future<List<QuestionModel>> getQuestions(String catId, String modId, String lessonId, {int limit = 10}) async {
    final snap = await _fs
        .collection(FS.categories)
        .doc(catId)
        .collection(FS.modules)
        .doc(modId)
        .collection(FS.lessons)
        .doc(lessonId)
        .collection(FS.questions)
        .orderBy('order')
        .limit(limit)
        .get();

    return snap.docs.map((d) => QuestionModel.fromFirestore(d)).toList();
  }
}
