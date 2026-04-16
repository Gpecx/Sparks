import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/covenant_model.dart';

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
        .collection('users')
        .doc(uid)
        .collection('covenants')
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) {
        // Inicializa defaults se vazio
        _createDefaultCovenants(uid);
      } else {
        activeCovenants = snap.docs.map((d) => CovenantModel.fromMap(d.data(), d.id)).toList();
        notifyListeners();
      }
    });
  }

  Future<void> _createDefaultCovenants(String uid) async {
    final defaults = [
      CovenantModel(
        id: 'cov_1', title: 'DISCIPLINA', objective: 'Completar 7 dias sem perder streak',
        reward: '+250 XP, Badge Exclusiva', currentProgress: 4, maxProgress: 7,
        isCompleted: false, trackingType: 'dias',
      ),
      CovenantModel(
        id: 'cov_2', title: 'VELOCIDADE', objective: '5 Batalhas PvP ganhas',
        reward: 'Skin exclusiva', currentProgress: 2, maxProgress: 5,
        isCompleted: false, trackingType: 'batalhas',
      ),
      CovenantModel(
        id: 'cov_3', title: 'MESTRIA', objective: 'Completar 100% módulo NR-35',
        reward: 'Certificado Virtual', currentProgress: 65, maxProgress: 100,
        isCompleted: false, trackingType: '%',
      ),
    ];
    
    final batch = FirebaseFirestore.instance.batch();
    for (var cov in defaults) {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid).collection('covenants').doc(cov.id);
      batch.set(ref, cov.toMap());
    }
    await batch.commit();
  }

  void addProgress(String id, int amount) {
    if (_uid == null) return;
    final index = activeCovenants.indexWhere((c) => c.id == id);
    if (index != -1) {
      final cov = activeCovenants[index];
      if (cov.isCompleted) return;

      int newProgress = cov.currentProgress + amount;
      bool completed = false;

      if (newProgress >= cov.maxProgress) {
        newProgress = cov.maxProgress;
        completed = true;
      }
      
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('covenants').doc(id).update({
        'currentProgress': newProgress,
        'isCompleted': completed,
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
