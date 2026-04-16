import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/routes/app_router.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/firebase_options.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─────────────────────────────────────────────────────────────────
//  MAIN — Inicializa Firebase antes de rodar o app
// ─────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 0. Carrega as variáveis de ambiente (.env)
  await dotenv.load(fileName: ".env");

  // 1. Inicializa o Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Escuta mudanças de autenticação para iniciar/parar o listener
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      // Usuário logou: inicia escuta em tempo real
      UserService().startListening();
      // Verifica se streak precisa ser resetado
      UserService().checkAndResetStreakIfNeeded();
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
    return MaterialApp.router(
      title: 'SPARK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}