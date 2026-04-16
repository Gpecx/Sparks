import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/covenant_model.dart';
import '../core/constants/fs.dart';


class CovenantService extends ChangeNotifier {
  static final CovenantService _instance = CovenantService._internal();

  factory CovenantService() {
    return _instance;
  }

  CovenantService._internal();

  List<CovenantModel> activeCovenants = [];
  StreamSubscription? _sub;
  String? _uid;

  void initialize(String uid) {
    if (_uid == uid) return;
    _sub?.cancel();
    _uid = uid;
    
    _sub = FirebaseFirestore.instance
        .collection(FS.users)
        .doc(uid)
        .collection(FS.covenants)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) {
        // Inicializa defaults se vazio
        _createDefaultCovenants(uid);
      } else {
        activeCovenants =
            snap.docs.map((d) => CovenantModel.fromMap(d.data(), d.id)).toList();
        notifyListeners();
      }
    });
  }

  Future<void> _createDefaultCovenants(String uid) async {
    final defaults = [
      CovenantModel(
        id: 'cov_1',
        title: 'DISCIPLINA',
        objective: 'Completar 7 dias sem perder streak',
        reward: '+250 XP, Badge Exclusiva',
        currentProgress: 0,
        maxProgress: 7,
        isCompleted: false,
        trackingType: 'dias',
      ),
      CovenantModel(
        id: 'cov_2',
        title: 'VELOCIDADE',
        objective: '5 Batalhas PvP ganhas',
        reward: 'Skin exclusiva',
        currentProgress: 0,
        maxProgress: 5,
        isCompleted: false,
        trackingType: 'batalhas',
      ),
      CovenantModel(
        id: 'cov_3',
        title: 'MESTRIA',
        objective: 'Completar 100% módulo NR-35',
        reward: 'Certificado Virtual',
        currentProgress: 0,
        maxProgress: 100,
        isCompleted: false,
        trackingType: '%',
      ),
    ];

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    for (final cov in defaults) {
      final ref = db
          .collection(FS.users)
          .doc(uid)
          .collection(FS.covenants)
          .doc(cov.id);
      batch.set(ref, cov.toMap());
    }
    await batch.commit();
  }

  /// Incrementa o progresso de um pacto e persiste na subcoleção.
  void addProgress(String id, int amount) {
    if (_uid == null) return;
    final index = activeCovenants.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final cov = activeCovenants[index];
    if (cov.isCompleted) return;

    final newProgress = (cov.currentProgress + amount).clamp(0, cov.maxProgress);
    final completed = newProgress >= cov.maxProgress;

    FirebaseFirestore.instance
        .collection(FS.users)
        .doc(_uid)
        .collection(FS.covenants)
        .doc(id)
        .update({
      'currentProgress': newProgress,
      'isCompleted': completed,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
