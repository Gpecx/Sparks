import 'package:go_router/go_router.dart';
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
import 'package:spark_app/screens/duel_screen.dart';
import 'package:spark_app/screens/error_simulation_screen.dart';
import 'package:spark_app/screens/categories_screen.dart';
import 'package:spark_app/screens/change_password_screen.dart';
import 'package:spark_app/screens/onboarding_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/home', builder: (context, state) => const MainShellScreen()),
      GoRoute(path: '/standards', builder: (context, state) => const TechnicalStandardsScreen()),
      GoRoute(path: '/standard-detail', builder: (context, state) => const StandardDetailScreen()),
      GoRoute(path: '/quiz', builder: (context, state) => const QuizScreen()),
      GoRoute(path: '/test-history', builder: (context, state) => const TestHistoryScreen()),
      GoRoute(path: '/store', builder: (context, state) => const StoreScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/achievements', builder: (context, state) => const AchievementsScreen()),
      GoRoute(path: '/clan', builder: (context, state) => const ClanScreen(isCreating: true)),
      GoRoute(path: '/duel', builder: (context, state) => const DuelScreen()),
      GoRoute(path: '/error-simulation', builder: (context, state) => const ErrorSimulationScreen()),
      GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
      GoRoute(path: '/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    ],
  );
}
