import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────────────────────────
//  OFFLINE SYNC SERVICE
//
//  Fluxo:
//   1. markLessonComplete() → grava na fila local (Hive)
//   2. Tenta enviar ao Firebase imediatamente
//   3. Se offline → entra na fila pendente
//   4. Quando conectar → _flushQueue() drena a fila
//
//  Boxes Hive:
//   - 'offline_queue' : lista de operações pendentes
//   - 'user_cache'    : snapshot do UserModel local
// ─────────────────────────────────────────────────────────────────

const _kQueueBox = 'offline_queue';
const _kUserBox = 'user_cache';

class OfflineSyncService {
  // ── Singleton ──────────────────────────────────────────────────
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final _db = FirebaseFirestore.instance;
  final _connectivity = Connectivity();

  Box? _queueBox;
  Box? _userBox;
  StreamSubscription<List<ConnectivityResult>>? _connectSub;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // ─────────────────────────────────────────────────────────────────
  //  INICIALIZAÇÃO
  // ─────────────────────────────────────────────────────────────────

  /// Chame uma vez em main(), após Firebase.initializeApp().
  Future<void> initialize() async {
    await Hive.initFlutter();
    _queueBox = await Hive.openBox(_kQueueBox);
    _userBox = await Hive.openBox(_kUserBox);

    // Estado inicial de conectividade
    final results = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(results);

    // Escuta mudanças de conectividade
    _connectSub = _connectivity.onConnectivityChanged.listen((results) async {
      final wasOffline = !_isOnline;
      _isOnline = _hasConnection(results);
      if (wasOffline && _isOnline) {
        debugPrint('[OfflineSync] Conexão restaurada → sincronizando fila...');
        await _flushQueue();
      }
    });

    // Tenta sincronizar ao iniciar caso já tenha fila pendente
    if (_isOnline) await _flushQueue();

    debugPrint('[OfflineSync] Inicializado. Online: $_isOnline | Fila: ${_queueBox?.length ?? 0}');
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  // ─────────────────────────────────────────────────────────────────
  //  CACHE DE PROGRESSO (fila de operações pendentes)
  // ─────────────────────────────────────────────────────────────────

  /// Enfileira uma operação de lição completada para sincronização.
  /// Se online, envia imediatamente; senão, salva na fila local.
  Future<void> enqueueMarkLesson({
    required String uid,
    required String catId,
    required String modId,
    required String lessonId,
    required int xpEarned,
    required int spEarned,
    String moduleName = '',
  }) async {
    final entry = {
      'type': 'mark_lesson',
      'uid': uid,
      'catId': catId,
      'modId': modId,
      'lessonId': lessonId,
      'xpEarned': xpEarned,
      'spEarned': spEarned,
      'moduleName': moduleName,
      'queuedAt': DateTime.now().toIso8601String(),
    };

    if (_isOnline) {
      try {
        await _executeMarkLesson(entry);
        return;
      } catch (e) {
        debugPrint('[OfflineSync] Falha ao sincronizar, enfileirando: $e');
      }
    }

    // Salva localmente se offline ou se o envio falhou
    await _queueBox?.add(entry);
    debugPrint('[OfflineSync] Enfileirado offline: $lessonId');
  }

  // ─────────────────────────────────────────────────────────────────
  //  CACHE DO USUÁRIO
  // ─────────────────────────────────────────────────────────────────

  /// Salva um snapshot do usuário localmente (chamado pelo UserService).
  Future<void> cacheUser(Map<String, dynamic> userData) async {
    await _userBox?.put('current_user', userData);
  }

  /// Retorna o usuário cacheado ou null se não houver.
  Map<String, dynamic>? getCachedUser() {
    final data = _userBox?.get('current_user');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Limpa o cache do usuário (logout).
  Future<void> clearUserCache() async {
    await _userBox?.delete('current_user');
  }

  // ─────────────────────────────────────────────────────────────────
  //  FLUSH DA FILA
  // ─────────────────────────────────────────────────────────────────

  /// Drena a fila de operações pendentes enviando ao Firebase.
  Future<void> _flushQueue() async {
    final box = _queueBox;
    if (box == null || box.isEmpty) return;

    final keys = box.keys.toList();
    debugPrint('[OfflineSync] Sincronizando ${keys.length} operações pendentes...');

    for (final key in keys) {
      final entry = box.get(key);
      if (entry == null) continue;

      final map = Map<String, dynamic>.from(entry as Map);
      try {
        if (map['type'] == 'mark_lesson') {
          await _executeMarkLesson(map);
        }
        await box.delete(key);
        debugPrint('[OfflineSync] ✓ Sincronizado: ${map['lessonId']}');
      } catch (e) {
        debugPrint('[OfflineSync] ✗ Falha ao sincronizar ${map['lessonId']}: $e');
        // Mantém na fila para tentar novamente
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  EXECUÇÃO DAS OPERAÇÕES
  // ─────────────────────────────────────────────────────────────────

  Future<void> _executeMarkLesson(Map<String, dynamic> entry) async {
    final uid = entry['uid'] as String;
    final catId = entry['catId'] as String;
    final modId = entry['modId'] as String;
    final lessonId = entry['lessonId'] as String;
    final xpEarned = entry['xpEarned'] as int;
    final spEarned = entry['spEarned'] as int;
    final moduleName = entry['moduleName'] as String? ?? '';

    final userRef = _db.collection('users').doc(uid);
    final progSnap = await userRef
        .collection('progress')
        .where('moduleId', isEqualTo: modId)
        .limit(1)
        .get();

    final batch = _db.batch();

    DocumentReference pRef;
    if (progSnap.docs.isNotEmpty) {
      pRef = progSnap.docs.first.reference;
    } else {
      pRef = userRef.collection('progress').doc();
      batch.set(pRef, {
        'moduleId': modId,
        'categoryId': catId,
        'moduleName': moduleName,
        'completedLessons': [],
        'progressPercent': 0.0,
        'isCompleted': false,
        'startedAt': FieldValue.serverTimestamp(),
        'lastAccessed': FieldValue.serverTimestamp(),
        'bestScore': 0,
        'attempts': 0,
      });
    }

    batch.update(pRef, {
      'completedLessons': FieldValue.arrayUnion([lessonId]),
      'lastAccessed': FieldValue.serverTimestamp(),
    });

    if (xpEarned > 0 || spEarned > 0) {
      batch.update(userRef, {
        'xp': FieldValue.increment(xpEarned),
        'weeklyXp': FieldValue.increment(xpEarned),
        'sparkPoints': FieldValue.increment(spEarned),
        'totalLessonsCompleted': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────
  //  LIMPEZA
  // ─────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _connectSub?.cancel();
    await _queueBox?.close();
    await _userBox?.close();
  }

  /// Retorna o número de operações na fila (útil para UI de diagnóstico).
  int get pendingCount => _queueBox?.length ?? 0;
}
