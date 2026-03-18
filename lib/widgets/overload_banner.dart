import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/services/overload_service.dart';

/// Banner/Overlay global que indica o evento "Sobrecarga" ativo.
/// Deve ser colocado no topo da árvore (ex: dentro do MainShellScreen).
/// Usa efeito de eletricidade pulsante (verde neon + glow).
class OverloadBanner extends StatefulWidget {
  final Widget child;
  const OverloadBanner({super.key, required this.child});

  @override
  State<OverloadBanner> createState() => _OverloadBannerState();
}

class _OverloadBannerState extends State<OverloadBanner>
    with SingleTickerProviderStateMixin {
  final OverloadService _overloadService = OverloadService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowAnim = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _overloadService.addListener(_onOverloadChanged);
  }

  void _onOverloadChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _overloadService.removeListener(_onOverloadChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Efeito elétrico nas bordas quando ativo ──
        if (_overloadService.isActive)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: _pulseAnim.value * 0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: _pulseAnim.value * 0.15),
                        blurRadius: _glowAnim.value,
                        spreadRadius: _glowAnim.value / 3,
                      ),
                      BoxShadow(
                        color: const Color(0xFF00FF41).withValues(alpha: _pulseAnim.value * 0.08),
                        blurRadius: _glowAnim.value * 2,
                        spreadRadius: _glowAnim.value / 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Conteúdo filho ──
        widget.child,

        // ── Banner no topo ──
        if (_overloadService.isActive)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: _pulseAnim.value * 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: _pulseAnim.value * 0.3),
                        blurRadius: _glowAnim.value,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Ícone pulsante de raio
                      Opacity(
                        opacity: _pulseAnim.value,
                        child: const Icon(Icons.bolt, color: Color(0xFF00FF41), size: 22),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'SOBRECARGA ATIVA!',
                              style: TextStyle(
                                color: Color(0xFF00FF41),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'XP em ${_overloadService.currentMultiplier.toInt()}x · Termina em ${_overloadService.remainingTimeFormatted}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _overloadService.remainingTimeFormatted,
                          style: const TextStyle(
                            color: Color(0xFF00FF41),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
