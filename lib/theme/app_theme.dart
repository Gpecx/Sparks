import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// EXS Solutions Brand Identity - Paleta de Cores Oficial
class AppColors {
  static const Color background = Color(0xFF061629);      // Azul escuro principal
  static const Color surface = Color(0xFF091E35);         // Azul escuro ligeiramente mais claro
  static const Color card = Color(0xFF0D2641);            // Card background
  static const Color cardBorder = Color(0xFF1D5F31);      // Verde médio para bordas
  static const Color primary = Color(0xFF00C402);         // Verde claro — cor principal de ação
  static const Color primaryLight = Color(0xFF33D035);    // Verde claro mais suave
  static const Color accent = Color(0xFF00C402);          // Mesmo verde como accent
  static const Color accentGreen = Color(0xFF1D5F31);     // Verde escuro complementar
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0C4D8);
  static const Color textMuted = Color(0xFF5A7A94);
  static const Color inputBackground = Color(0xFF0D2641);
  static const Color inputBorder = Color(0xFF1D5F31);
  static const Color error = Color(0xFFFF5252);
  static const Color errorDark = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA726);
  static const Color blue = Color(0xFF42A5F5);
  static const Color gold = Color(0xFFFFD700);
  static const Color orange = Color(0xFFFF9800);
  static const Color navBarBackground = Color(0xFF040F1C);
  static const Color greenDark = Color(0xFF1D5F31);
  static const Color greenBright = Color(0xFF00C402);

  // ── Tokens semânticos (substituem cores hardcoded espalhadas) ──
  static const Color surfaceAlt = Color(0xFF0B1410);   // superfície escura alternativa
  static const Color successBg = Color(0xFF1a2e1a);    // fundo de destaque de sucesso
  static const Color dangerBg = Color(0xFF2A1212);     // fundo de destaque de erro
  static const Color warningAmber = Color(0xFFFFB300); // avisos / dev mode / streak
  static const Color amberBg = Color(0xFF2A1800);      // fundo de destaque de aviso
}

/// Escala única de raio de borda do SPARK.
///
/// Antes existiam 16 valores distintos (2–24) espalhados pelas telas; estes
/// quatro cobrem todos os casos e mantêm os cantos visualmente consistentes.
class AppRadius {
  const AppRadius._();

  static const double sm = 8;     // chips, inputs, botões compactos
  static const double md = 12;    // cards e diálogos padrão
  static const double lg = 16;    // cards de destaque, bottom sheets
  static const double pill = 999; // elementos totalmente arredondados
}

/// Escala única de espaçamento (múltiplos de 4).
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.exo2TextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
          displayMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          labelLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
