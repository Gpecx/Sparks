import 'package:flutter/material.dart';

/// Reusable responsive tap widget with scale & opacity animation.
/// Wraps any child to give it interactive feedback (press effect + pointer cursor).
class ResponsiveTapWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleEnd;
  final double opacityEnd;

  const ResponsiveTapWidget({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleEnd = 0.95,
    this.opacityEnd = 0.7,
  });

  @override
  State<ResponsiveTapWidget> createState() => _ResponsiveTapWidgetState();
}

class _ResponsiveTapWidgetState extends State<ResponsiveTapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scaleEnd).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: widget.opacityEnd).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
