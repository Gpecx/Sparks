import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/progress_model.dart';
import '../core/constants/fs.dart';

// keepAlive = true: mantém o stream ativo mesmo quando o widget sai da tela
// (ex: ao abrir QuizScreen via Navigator.push), evitando loading ao voltar.
final userProgressProvider = StreamProvider<List<ProgressModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection(FS.users)
      .doc(uid)
      .collection(FS.progress)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ProgressModel.fromFirestore(doc))
          .toList());
});
