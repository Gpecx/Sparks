import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/welcome_screen.dart';
import 'package:spark_app/screens/login_screen.dart';
import 'package:spark_app/screens/register_screen.dart';
import 'package:spark_app/screens/forgot_password_screen.dart';
import 'package:spark_app/screens/main_shell_screen.dart';
import 'package:spark_app/screens/technical_standards_screen.dart';
import 'package:spark_app/screens/standard_detail_screen.dart';
import 'package:spark_app/screens/quiz_screen.dart';
import 'package:spark_app/screens/test_history_screen.dart';
import 'package:spark_app/screens/store_screen.dart';
import 'package:spark_app/screens/settings_screen.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/screens/clan_screen.dart';

void main() {
  runApp(const SparkApp());
}

class SparkApp extends StatelessWidget {
  const SparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPARK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const MainShellScreen(),
        '/standards': (context) => const TechnicalStandardsScreen(),
        '/standard-detail': (context) => const StandardDetailScreen(),
        '/quiz': (context) => const QuizScreen(),
        '/test-history': (context) => const TestHistoryScreen(),
        '/store': (context) => const StoreScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/achievements': (context) => const AchievementsScreen(),
        '/clan': (context) => const ClanScreen(isCreating: true),
      },
    );
  }
}
