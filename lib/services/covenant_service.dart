import 'package:flutter/material.dart';
import '../models/covenant_model.dart';

class CovenantService extends ChangeNotifier {
  static final CovenantService _instance = CovenantService._internal();

  factory CovenantService() {
    return _instance;
  }

  CovenantService._internal();

  // Mock list of active covenants for the week
  List<CovenantModel> activeCovenants = [
    CovenantModel(
      id: 'cov_1',
      title: 'DISCIPLINA',
      objective: 'Completar 7 dias sem perder streak',
      reward: '+250 XP, Badge Exclusiva',
      currentProgress: 4,
      maxProgress: 7,
      isCompleted: false,
      trackingType: 'dias',
    ),
    CovenantModel(
      id: 'cov_2',
      title: 'VELOCIDADE',
      objective: '5 Batalhas PvP ganhas',
      reward: 'Skin exclusiva',
      currentProgress: 2,
      maxProgress: 5,
      isCompleted: false,
      trackingType: 'batalhas',
    ),
    CovenantModel(
      id: 'cov_3',
      title: 'MESTRIA',
      objective: 'Completar 100% módulo NR-35',
      reward: 'Certificado Virtual',
      currentProgress: 65,
      maxProgress: 100,
      isCompleted: false,
      trackingType: '%',
    ),
  ];

  void addProgress(String id, int amount) {
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

      activeCovenants[index] = CovenantModel(
        id: cov.id,
        title: cov.title,
        objective: cov.objective,
        reward: cov.reward,
        currentProgress: newProgress,
        maxProgress: cov.maxProgress,
        isCompleted: completed,
        trackingType: cov.trackingType,
      );
      
      notifyListeners();
    }
  }
}
