import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/models/covenant_model.dart';
import 'package:spark_app/core/constants/fs.dart';

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
      'reward': '+250 XP, Badge Exclusiva',
      'maxProgress': 7,
      'trackingType': 'dias',
    },
    {
      'id': 'cov_velocidade',
      'title': 'VELOCIDADE',
      'objective': '5 Batalhas PvP ganhas',
      'reward': 'Skin exclusiva',
      'maxProgress': 5,
      'trackingType': 'batalhas',
    },
    {
      'id': 'cov_mestria',
      'title': 'MESTRIA',
      'objective': 'Completar 100% do módulo NR-35',
      'reward': 'Certificado Virtual',
      'maxProgress': 100,
      'trackingType': '%',
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
      'reward': '+200 XP, Faísca Dupla',
      'maxProgress': 20,
      'trackingType': 'acertos',
    },
    {
      'id': 'cov_lideranca',
      'title': 'LIDERANÇA',
      'objective': 'Ficar no top 10 do ranking semanal',
      'reward': 'Badge de Líder',
      'maxProgress': 1,
      'trackingType': 'conquista',
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

    _sub = FirebaseFirestore.instance
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
    final db = FirebaseFirestore.instance;
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

    final db = FirebaseFirestore.instance;
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
    await FirebaseFirestore.instance
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
    await FirebaseFirestore.instance
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
  void addProgress(String id, int amount) {
    if (_uid == null) return;
    final index = _covenants.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final cov = _covenants[index];
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
