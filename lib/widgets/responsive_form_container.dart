import 'package:flutter/material.dart';

/// Centraliza e limita a largura do conteúdo em telas largas (desktop/web),
/// evitando formulários "esticados". Em telas estreitas (celular) o conteúdo
/// ocupa toda a largura normalmente.
class ResponsiveFormContainer extends StatelessWidget {
  const ResponsiveFormContainer({
    super.key,
    required this.child,
    this.maxWidth = 460,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
