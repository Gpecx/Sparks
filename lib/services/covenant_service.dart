import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spark_app/models/covenant_model.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/services/user_service.dart';

/// Manages weekly covenants (pacts) for the current user.
///
/// Responsibilities:
///  - Expose a catalog of available covenants
///  - Allow user to select/deselect covenants for the current week
///  - Auto-reset at the start of each new week (re-selects previous choices)
///  - Track progress via addProgress()
class CovenantService extends ChangeNotifier {
  static final CovenantService _instance = CovenantService._internal();
  factory CovenantService() => _instance;
  CovenantService._internal();

  // ── Static catalog — definitions only, no runtime state ─────────
  static const List<Map<String, dynamic>> _catalog = [
    {
      'id': 'cov_disciplina',
      'title': 'DISCIPLINA',
      'objective': 'Completar 7 dias sem perder streak',
      'reward': '+250 XP',
      'maxProgress': 7,
      'trackingType': 'dias',
    },
    {
      'id': 'cov_conhecimento',
      'title': 'CONHECIMENTO',
      'objective': 'Completar 10 lições na semana',
      'reward': '+150 XP',
      'maxProgress': 10,
      'trackingType': 'lições',
    },
    {
      'id': 'cov_precisao',
      'title': 'PRECISÃO',
      'objective': 'Acertar 20 perguntas sem errar',
      'reward': '+200 XP',
      'maxProgress': 20,
      'trackingType': 'acertos',
    },
  ];

  List<CovenantModel> _covenants = [];
  bool _isLoading = true;
  StreamSubscription? _sub;
  String? _uid;

  // ── Public getters ───────────────────────────────────────────────

  bool get isLoading => _isLoading;

  /// All covenants loaded for this user (selected + available).
  List<CovenantModel> get allCovenants => _covenants;

  /// Covenants selected by the user for the current week.
  List<CovenantModel> get activeCovenants =>
      _covenants.where((c) => c.isSelected).toList();

  /// Covenants not yet selected this week.
  List<CovenantModel> get availableCovenants =>
      _covenants.where((c) => !c.isSelected).toList();

  String get currentWeekKey {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final week = ((dayOfYear - now.weekday + 10) / 7).floor();
    return '${now.year}-W${week.toString().padLeft(2, '0')}';
  }

  // ── Initialization ───────────────────────────────────────────────

  void initialize(String uid) {
    if (_uid == uid) return;
    _sub?.cancel();
    _uid = uid;
    _isLoading = true;
    notifyListeners();

    _sub = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
        .collection(FS.users)
        .doc(uid)
        .collection(FS.covenants)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) {
        // First time initialization — seed the catalog
        await _seedCatalog(uid);
        return; // Snapshot will trigger again after seeding
      }

      _covenants = snap.docs.map((d) => CovenantModel.fromMap(d.data(), d.id)).toList();
      _isLoading = false;
      notifyListeners();

      await _checkWeeklyReset(uid);
    });
  }

  /// Seeds the full catalog into Firestore for a new user (batch write).
  Future<void> _seedCatalog(String uid) async {
    final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
    final batch = db.batch();

    for (final def in _catalog) {
      final ref = db
          .collection(FS.users)
          .doc(uid)
          .collection(FS.covenants)
          .doc(def['id'] as String);

      batch.set(ref, {
        ...def,
        'currentProgress': 0,
        'isCompleted': false,
        'isSelected': false,
        'weekKey': '',
      });
    }
    await batch.commit();
  }

  /// Checks if the week has rolled over; if so, resets and re-selects previous choices.
  Future<void> _checkWeeklyReset(String uid) async {
    final weekKey = currentWeekKey;
    final needReset = _covenants
        .where((c) => c.isSelected && c.weekKey.isNotEmpty && c.weekKey != weekKey)
        .toList();


    if (needReset.isEmpty) return;

    final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
    final batch = db.batch();

    for (final cov in needReset) {
      final ref = db
          .collection(FS.users)
          .doc(uid)
          .collection(FS.covenants)
          .doc(cov.id);
      // Reset progress but keep isSelected: true for the new week
      batch.update(ref, {
        'currentProgress': 0,
        'isCompleted': false,
        'weekKey': weekKey,
      });
    }
    await batch.commit();
  }

  // ── Selection ────────────────────────────────────────────────────

  Future<void> selectCovenant(String id) async {
    if (_uid == null) return;
    await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
        .collection(FS.users)
        .doc(_uid)
        .collection(FS.covenants)
        .doc(id)
        .update({
      FS.isSelected: true,
      FS.weekKey: currentWeekKey,
    });
  }

  Future<void> deselectCovenant(String id) async {
    if (_uid == null) return;
    await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
        .collection(FS.users)
        .doc(_uid)
        .collection(FS.covenants)
        .doc(id)
        .update({
      FS.isSelected: false,
      FS.weekKey: '',
    });
  }

  // ── Progress ─────────────────────────────────────────────────────

  /// Increments the progress of a covenant and persists to Firestore.
  Future<void> addProgress(String id, int amount) async {
    if (_uid == null) return;
    final index = _covenants.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final cov = _covenants[index];
    if (cov.isCompleted) return;
    if (!cov.isSelected) return;

    final newProgress = (cov.currentProgress + amount).clamp(0, cov.maxProgress);
    final completed = newProgress >= cov.maxProgress;

    await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
        .collection(FS.users)
        .doc(_uid)
        .collection(FS.covenants)
        .doc(id)
        .update({
      'currentProgress': newProgress,
      'isCompleted': completed,
    });

    if (completed) {
      int xpReward = 0;
      if (cov.reward.contains('150')) xpReward = 150;
      if (cov.reward.contains('200')) xpReward = 200;
      if (cov.reward.contains('250')) xpReward = 250;

      if (xpReward > 0) {
        await UserService().addXp(xpReward, source: 'pacto_$id');
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
