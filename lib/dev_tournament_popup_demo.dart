// DEMO ISOLADA — apenas para visualizar o popup de vitória do torneio.
// NÃO toca em Firestore, XP, nem em nenhuma conta. Rodar com:
//   flutter run -d linux -t lib/dev_tournament_popup_demo.dart
// Pode apagar este arquivo depois.
import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/leaderboard_screen.dart';

void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const _DemoHome(),
    );
  }
}

class _DemoHome extends StatelessWidget {
  const _DemoHome();

  void _show(BuildContext context, int place, int prize) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => TournamentWinDialog(place: place, prize: prize),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo — Popup de Vitória do Torneio'),
        backgroundColor: AppColors.card,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Clique para ver o popup de cada colocação\n(puramente visual — não afeta nada)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 28),
            _btn(context, '🥇  1º lugar  (+500 XP)', AppColors.gold,
                () => _show(context, 1, 500)),
            const SizedBox(height: 14),
            _btn(context, '🥈  2º lugar  (+250 XP)', const Color(0xFFC9D2DC),
                () => _show(context, 2, 250)),
            const SizedBox(height: 14),
            _btn(context, '🥉  3º lugar  (+100 XP)', const Color(0xFFCD7F32),
                () => _show(context, 3, 100)),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext context, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 280,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }
}
