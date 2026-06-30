import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────
//  FCM SERVICE — Firebase Cloud Messaging
//
//  Responsabilidades:
//   - Solicitar permissão de notificação
//   - Obter e persistir FCM token em users/{uid}/fcmToken
//   - Atualizar token quando rotacionado
//   - Expor método para envio de notificação local ao receber push
// ─────────────────────────────────────────────────────────────────

/// Handler de background — deve ser top-level (fora de classes).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Apenas logga; sem inicialização extra necessária pois o Firebase
  // já foi inicializado pelo plugin antes de chamar este handler.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FcmService {
  // ── Singleton ──────────────────────────────────────────────────
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
  final _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────────────
  //  INICIALIZAÇÃO
  // ─────────────────────────────────────────────────────────────────

  /// Chame uma única vez em main(), após Firebase.initializeApp().
  Future<void> initialize() async {
    // onBackgroundMessage usa Service Worker API que não é suportada no
    // Safari iOS (< 16.4) e pode lançar exceção silenciosa travando o app.
    // Restringimos ao mobile onde funciona corretamente.
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Solicita permissão — envolvido em try/catch pois no Safari iOS o popup
    // pode ser bloqueado ou a API pode não estar disponível, o que jogaria
    // uma exceção e impediria o runApp() de ser chamado (tela branca).
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _saveTokenToFirestore();
      }
    } catch (e) {
      debugPrint('[FCM] requestPermission não suportado neste browser: $e');
    }

    // Atualiza token quando rotacionado pelo FCM
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Mensagem recebida com app em foreground → apenas loga
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
    });
  }

  // ─────────────────────────────────────────────────────────────────
  //  TOKEN
  // ─────────────────────────────────────────────────────────────────

  Future<void> _saveTokenToFirestore() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Token salvo no Firestore.');
    } catch (e) {
      debugPrint('[FCM] Erro ao salvar token: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FCM] Erro ao atualizar token: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  SALVA TOKEN APÓS LOGIN (chamado pelo UserService.startListening)
  // ─────────────────────────────────────────────────────────────────

  /// Chame após o usuário fazer login para garantir que o token
  /// seja salvo mesmo que o app tenha sido aberto antes do login.
  Future<void> saveTokenAfterLogin() => _saveTokenToFirestore();
}
