import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/routes/app_router.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/services/fcm_service.dart';
import 'package:spark_app/services/offline_sync_service.dart';
import 'package:spark_app/screens/welcome_screen.dart';
import 'package:spark_app/firebase_options.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─────────────────────────────────────────────────────────────────
//  MAIN — Inicializa Firebase, Crashlytics e App
// ─────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 0. Carrega as variáveis de ambiente (.env)
  await dotenv.load(fileName: ".env");

  // 1. Inicializa o Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 1b. Inicializa FCM (permissão + handlers)
  await FcmService().initialize();

  // 1c. Inicializa sincronização offline (Hive + Connectivity)
  await OfflineSyncService().initialize();

  // 2. Erros globais via Crashlytics (Tratamento de Produção)
  // Repassa todas as exceções não capturadas pelo framework Flutter
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Repassa exceções assíncronas que o Flutter não consegue pegar nativamente
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // 2. Escuta mudanças de autenticação para iniciar/parar o listener
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      // Impede contenção de escrita durante o cadastro (bloqueia deadlock do Firestore)
      if (!WelcomeScreen.skipAutoLogin) {
        // Usuário logou normalmente: inicia escuta em tempo real
        UserService().startListening();
        // Verifica se streak precisa ser resetado
        UserService().checkAndResetStreakIfNeeded();
      }
    } else {
      // Usuário saiu: para a escuta
      UserService().stopListening();
    }
  });

  runApp(
    const ProviderScope(
      child: SparkApp(),
    ),
  );
}

class SparkApp extends StatelessWidget {
  const SparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tratamento de erro global na UI
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _GlobalErrorWidget(details: details);
    };

    return MaterialApp.router(
      title: 'SPARK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  GLOBAL ERROR WIDGET — Exibido quando um widget lança exceção
// ─────────────────────────────────────────────────────────────────
class _GlobalErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;

  const _GlobalErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Erro inesperado na tela',
      child: Material(
        color: const Color(0xFF0A0A0F),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 56,
                  semanticLabel: 'Ícone de aviso',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Algo deu errado',
                  style: TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Um componente não pôde ser renderizado.\nRecarregue o aplicativo.',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode) ...[                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0000),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      details.exceptionAsString(),
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}