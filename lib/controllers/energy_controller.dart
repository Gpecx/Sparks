import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:spark_app/services/overload_service.dart';
import 'package:spark_app/services/user_service.dart';

// ─────────────────────────────────────────────────────────────────
//  ENERGY CONTROLLER — VERSÃO COM FIREBASE
//
//  MUDANÇAS EM RELAÇÃO AO ORIGINAL:
//  - addXp() agora persiste no Firestore via UserService
//  - addSparkPoints() e spendSparkPoints() sincronizam com Firestore
//  - Os getters de xp, sparkPoints e level lêem do UserService
//    (fonte única de verdade = Firestore)
//  - A bateria de energia local (gameplay) continua local pois é
//    volátil e não precisa ser persistida entre sessões
// ─────────────────────────────────────────────────────────────────

class EnergyController extends ChangeNotifier {
  // ── Configurações ────────────────────────────────────────────────
  static const int maxEnergy = 25;
  static const int entryCost = 1;
  static const int errorCost = 1;
  static const int regenIntervalMinutes = 5;
  static const int fullRechargeSparkCost = 50;
  static const int streakBonusThreshold = 3;

  // ── Singleton ────────────────────────────────────────────────────
  static final EnergyController _instance = EnergyController._internal();
  factory EnergyController() => _instance;
  EnergyController._internal();

  // ── Estado LOCAL (bateria de gameplay) ──────────────────────────
  int _energy = maxEnergy;
  bool _isPremiumUser = false;
  int _streak = 0; // streak de acertos na SESSÃO (diferente do streak diário)
  Timer? _regenTimer;
  DateTime? _nextRegenTime;

  // ── UserService (fonte de verdade para dados persistidos) ────────
  final UserService _userService = UserService();

  // ── Getters que lêem do Firestore via UserService ────────────────
  int get xp => _userService.xp;
  int get sparkPoints => _userService.sparkPoints;
  int get userLevel => _userService.level;

  // ── Getters locais (bateria de gameplay) ────────────────────────
  int get energy => _energy;
  bool get isPremiumUser => _isPremiumUser;
  int get streak => _streak;

  bool get hasEnergy => _isPremiumUser || _energy > 0;
  bool get isRecharging => _energy < maxEnergy && !_isPremiumUser;
  DateTime? get nextRegenTime => _nextRegenTime;
  String get energyDisplay => _isPremiumUser ? 'MAX' : '$_energy';

  String get regenTimeRemaining {
    if (_nextRegenTime == null || !isRecharging) return '';
    final diff = _nextRegenTime!.difference(DateTime.now());
    if (diff.isNegative) return '0:00';
    final mins = diff.inMinutes;
    final secs = diff.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────────────
  //  AÇÕES — BATERIA LOCAL
  // ─────────────────────────────────────────────────────────────────

  bool spendEntryEnergy() {
    if (_isPremiumUser) return true;
    if (_energy < entryCost) return false;
    _energy -= entryCost;
    _startRegenIfNeeded();
    notifyListeners();
    return true;
  }

  bool spendErrorEnergy() {
    if (_isPremiumUser) return true;
    if (_energy > 0) {
      _energy -= errorCost;
      _startRegenIfNeeded();
      notifyListeners();
    }
    return _energy > 0;
  }

  int registerCorrectAnswer() {
    _streak++;
    int bonus = 0;
    if (_streak >= streakBonusThreshold && _streak % streakBonusThreshold == 0) {
      bonus = Random().nextInt(3) + 1;
      _energy = (_energy + bonus).clamp(0, maxEnergy);
    }
    notifyListeners();
    return bonus;
  }

  void resetStreak() {
    _streak = 0;
    notifyListeners();
  }

  void setPremium(bool value) {
    _isPremiumUser = value;
    if (value) _stopRegen();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  //  AÇÕES — PERSISTIDAS NO FIRESTORE
  // ─────────────────────────────────────────────────────────────────

  /// Adiciona XP. Aplica multiplicador de Sobrecarga e persiste.
  Future<void> addXp(int amount) async {
    final finalAmount = OverloadService().applyMultiplier(amount);
    await _userService.addXp(finalAmount);
    notifyListeners(); // getter xp reflete novo valor do UserService
  }

  /// Adiciona Pontos Spark e persiste.
  Future<void> addSparkPoints(int amount) async {
    await _userService.addSparkPoints(amount);
    notifyListeners();
  }

  /// Gasta Pontos Spark. Retorna true se bem-sucedido.
  Future<bool> spendSparkPoints(int amount) async {
    final success = await _userService.spendSparkPoints(amount);
    if (success) notifyListeners();
    return success;
  }

  /// Recarga total da bateria com Spark Points.
  Future<bool> rechargeWithSparks() async {
    final success = await spendSparkPoints(fullRechargeSparkCost);
    if (success) {
      _energy = maxEnergy;
      _stopRegen();
      notifyListeners();
    }
    return success;
  }

  // ─────────────────────────────────────────────────────────────────
  //  REGENERAÇÃO POR TEMPO (LOCAL)
  // ─────────────────────────────────────────────────────────────────

  void _startRegenIfNeeded() {
    if (_regenTimer != null || _energy >= maxEnergy || _isPremiumUser) return;
    _nextRegenTime = DateTime.now().add(const Duration(minutes: regenIntervalMinutes));
    _regenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_energy >= maxEnergy || _isPremiumUser) {
        _stopRegen();
        return;
      }
      if (DateTime.now().isAfter(_nextRegenTime!)) {
        _energy = (_energy + 1).clamp(0, maxEnergy);
        if (_energy < maxEnergy) {
          _nextRegenTime = DateTime.now().add(const Duration(minutes: regenIntervalMinutes));
        } else {
          _stopRegen();
        }
        notifyListeners();
      }
      notifyListeners();
    });
  }

  void _stopRegen() {
    _regenTimer?.cancel();
    _regenTimer = null;
    _nextRegenTime = null;
  }

  @override
  void dispose() {
    _stopRegen();
    super.dispose();
  }
}