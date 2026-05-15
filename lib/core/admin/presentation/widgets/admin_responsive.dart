import 'package:flutter/material.dart';

/// Classe para gerenciar breakpoints e responsividade do painel admin
class AdminResponsive {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < mobileBreakpoint;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= mobileBreakpoint && MediaQuery.of(context).size.width < tabletBreakpoint;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= tabletBreakpoint;

  static double getGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  static double getGridChildAspectRatio(BuildContext context) {
    if (isMobile(context)) return 3.0;
    if (isTablet(context)) return 2.2;
    return 1.5;
  }

  static EdgeInsets getPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(12);
    if (isTablet(context)) return const EdgeInsets.all(20);
    return const EdgeInsets.all(32);
  }

  static double getSidebarWidth(BuildContext context) {
    if (isMobile(context)) return 0;
    if (isTablet(context)) return 240;
    return 280;
  }

  static double getCardHeight(BuildContext context) {
    if (isMobile(context)) return 120;
    if (isTablet(context)) return 140;
    return 160;
  }

  static TextStyle getTitleStyle(BuildContext context) {
    if (isMobile(context)) return const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    if (isTablet(context)) return const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    return const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
  }

  static TextStyle getSubtitleStyle(BuildContext context) {
    if (isMobile(context)) return const TextStyle(fontSize: 11);
    if (isTablet(context)) return const TextStyle(fontSize: 12);
    return const TextStyle(fontSize: 13);
  }
}

/// Widget que se adapta automaticamente ao tamanho da tela
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(
      context,
      AdminResponsive.isMobile(context),
      AdminResponsive.isTablet(context),
      AdminResponsive.isDesktop(context),
    );
  }
}
