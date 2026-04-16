import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/services/overload_service.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/services/achievement_service.dart';
import 'package:spark_app/models/user_model.dart';

/// Controlador global de energia do SPARK.
/// Gerencia bateria, regeneração por tempo, streaks e status premium.
class EnergyController extends ChangeNotifier {
  // ============================================================
  // CONFIGURAÇÕES EDITÁVEIS
  // ============================================================
  static const int maxEnergy = 25;
  static const int entryCost = 1;
  static const int errorCost = 1;
  static const int regenIntervalMinutes = 5; // 1 unidade a cada X minutos
  static const int fullRechargeSparkCost = 50; // Custo em Sparks para recarga total
  static const int streakBonusThreshold = 3; // Acertos seguidos para bônus

  // ============================================================
  // SINGLETON
  // ============================================================
  static final EnergyController _instance = EnergyController._internal();
  factory EnergyController() => _instance;
  EnergyController._internal();

  // ============================================================
  // STATE
  // ============================================================
  int _energy = maxEnergy;
  int _sparkPoints = 4500; // Moeda do jogo (Pontos Spark / Gems)
  bool _isPremiumUser = false;
  int _streak = 0;
  int _xp = 1500; // Começando com algum XP pra mostrar no mock
  Timer? _regenTimer;
  DateTime? _nextRegenTime;

  // Getters
  int get energy => _energy;
  int get sparkPoints => _sparkPoints;
  bool get isPremiumUser => _isPremiumUser;
  int get streak => _streak;
  int get xp => _xp;
  int get userLevel => (_xp ~/ 500) + 1; // A cada 500 XP = 1 Level
  
  bool get hasEnergy => _isPremiumUser || _energy > 0;
  bool get isRecharging => _energy < maxEnergy && !_isPremiumUser;
  DateTime? get nextRegenTime => _nextRegenTime;

  String get energyDisplay => _isPremiumUser ? '∞' : '$_energy';

  /// Tempo restante formatado para a próxima recarga
  String get regenTimeRemaining {
    if (_nextRegenTime == null || !isRecharging) return '';
    final diff = _nextRegenTime!.difference(DateTime.now());
    if (diff.isNegative) return '0:00';
    final mins = diff.inMinutes;
    final secs = diff.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // LOAD USER DA FONTE DE DADOS
  // ============================================================
  void loadUser(UserModel user) {
    _energy = user.energy;
    _sparkPoints = user.sparkPoints;
    _isPremiumUser = user.isPremium;
    _streak = user.streak;
    _xp = user.xp;
    
    // Atualiza lógica de regen inicial a partir do banco
    if (!user.isPremium && user.energy < maxEnergy && user.energyLastRegen != null) {
      final lastRegen = user.energyLastRegen!;
      final now = DateTime.now();
      final diff = now.difference(lastRegen).inMinutes;
      final gained = diff ~/ regenIntervalMinutes;
      
      int newEnergy = (user.energy + gained).clamp(0, maxEnergy);
      if (newEnergy > _energy) {
        _energy = newEnergy;
        // Iniciar regen se não chegou ao máximo
        if (_energy < maxEnergy) {
          int remainder = diff % regenIntervalMinutes;
          _nextRegenTime = now.add(Duration(minutes: regenIntervalMinutes - remainder));
          UserService().regenEnergy(user.uid);
        }
      } else {
        _nextRegenTime = lastRegen.add(Duration(minutes: regenIntervalMinutes));
      }
      _startRegenTimer();
    }
    notifyListeners();
  }

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ============================================================
  // AÇÕES
  // ============================================================

  /// Tenta gastar energia ao iniciar uma lição. Retorna true se sucesso.
  bool spendEntryEnergy() {
    if (_isPremiumUser) return true;
    if (_energy < entryCost) return false;
    _energy -= entryCost;
    
    final uid = _currentUid;
    if (uid != null) {
      UserService().spendEnergy(uid);
    }
    
    _startRegenIfNeeded();
    notifyListeners();
    return true;
  }

  /// Gasta energia por erro no quiz. Retorna true se ainda tem.
  bool spendErrorEnergy() {
    if (_isPremiumUser) return true;
    if (_energy > 0) {
      _energy -= errorCost;
      
      final uid = _currentUid;
      if (uid != null) {
        UserService().spendEnergy(uid);
      }
      
      _startRegenIfNeeded();
      notifyListeners();
    }
    return _energy > 0;
  }

  /// Tenta gastar Pontos Spark (para apostas, etc). Retorna true se saldo for suficiente.
  bool spendSparkPoints(int amount) {
    if (_sparkPoints >= amount) {
      _sparkPoints -= amount;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Registra um acerto. Se atingir streak, dá bônus aleatório.
  int registerCorrectAnswer() {
    _streak++;
    int bonus = 0;
    if (_streak >= streakBonusThreshold && _streak % streakBonusThreshold == 0) {
      bonus = Random().nextInt(3) + 1; // Bônus de 1 a 3
      _energy = (_energy + bonus).clamp(0, maxEnergy);
    }
    
    final uid = _currentUid;
    if (uid != null) {
      UserService().updateStreak(uid);
      AchievementService().checkStreakAchievements(uid, _streak);
    }
    
    notifyListeners();
    return bonus;
  }

  /// Reseta streak em erro
  void resetStreak() {
    _streak = 0;
    
    final uid = _currentUid;
    if (uid != null) {
      // In a real app we might reset streak in DB immediately too.
      // UserService().updateStreak doesn't explicitly reset, so we could add a reset method 
      // or assume logic if needed. But locally we reset it.
    }
    
    notifyListeners();
  }

  /// Recarga completa com Pontos Spark (Gems)
  bool rechargeWithSparks() {
    if (_sparkPoints < fullRechargeSparkCost) return false;
    _sparkPoints -= fullRechargeSparkCost;
    _energy = maxEnergy;
    
    final uid = _currentUid;
    if (uid != null) {
      UserService().spendSP(uid, fullRechargeSparkCost);
    }
    
    _stopRegen();
    notifyListeners();
    return true;
  }

  /// Ativa o modo Premium (energia infinita)
  void setPremium(bool value) {
    _isPremiumUser = value;
    if (value) _stopRegen();
    notifyListeners();
  }

  /// Adiciona pontos spark (ex: compra na loja) e persiste no Firestore.
  void addSparkPoints(int amount) {
    _sparkPoints += amount;
    final uid = _currentUid;
    if (uid != null) {
      UserService().addSP(uid, amount);
    }
    notifyListeners();
  }

  /// Adiciona XP após finalizar lição (aplica multiplicador de Sobrecarga se ativo)
  /// e persiste no Firestore via [UserService].
  void addXp(int amount) {
    final finalAmount = OverloadService().applyMultiplier(amount);
    _xp += finalAmount;
    final uid = _currentUid;
    if (uid != null) {
      UserService().addXp(uid, finalAmount);
    }
    notifyListeners();
  }

  // ============================================================
  // REGENERAÇÃO POR TEMPO
  // ============================================================
  void _startRegenIfNeeded() {
    if (_regenTimer != null || _energy >= maxEnergy || _isPremiumUser) return;
    if (_nextRegenTime == null) {
        _nextRegenTime = DateTime.now().add(const Duration(minutes: regenIntervalMinutes));
    }
    _startRegenTimer();
  }

  void _startRegenTimer() {
    if (_regenTimer != null) return;
    _regenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_energy >= maxEnergy || _isPremiumUser) {
        _stopRegen();
        return;
      }
      if (_nextRegenTime != null && DateTime.now().isAfter(_nextRegenTime!)) {
        _energy = (_energy + 1).clamp(0, maxEnergy);
        if (_energy < maxEnergy) {
          _nextRegenTime = DateTime.now().add(const Duration(minutes: regenIntervalMinutes));
        } else {
          _stopRegen();
        }
        
        final uid = _currentUid;
        if (uid != null) {
          UserService().regenEnergy(uid);
        }
        
        notifyListeners();
      }
      notifyListeners(); // para atualizar o timer na UI
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