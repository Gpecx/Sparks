import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/access_code_service.dart';

/// Painel de estatísticas de usuários — dados reais via Cloud Function.
///
/// • Total de usuários cadastrados
/// • Usuários ativos nos últimos [_activeThresholdMinutes] minutos
///   (baseado no campo `updatedAt` de cada usuário)
///
/// Auto-atualiza a cada [_refreshInterval].
class AdminStatsPanel extends StatefulWidget {
  const AdminStatsPanel({super.key});

  @override
  State<AdminStatsPanel> createState() => _AdminStatsPanelState();
}

class _AdminStatsPanelState extends State<AdminStatsPanel> {
  static const int _activeThresholdMinutes = 15;
  static const Duration _refreshInterval = Duration(seconds: 30);

  final _service = AccessCodeService.instance;

  bool _loading = true;
  String? _error;
  int _total = 0;
  int _active = 0;
  DateTime? _lastUpdated;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(_refreshInterval, (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = _total == 0; // só mostra loading na primeira vez
      _error = null;
    });
    try {
      final users = await _service.listUsers();
      if (!mounted) return;

      final cutoff = DateTime.now()
          .subtract(const Duration(minutes: _activeThresholdMinutes));

      int activeCount = 0;
      for (final u in users) {
        final raw = u['updatedAt'];
        DateTime? dt;
        if (raw is String && raw.isNotEmpty) dt = DateTime.tryParse(raw);
        if (dt != null && dt.isAfter(cutoff)) activeCount++;
      }

      setState(() {
        _total = users.length;
        _active = activeCount;
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final t = dt.toLocal();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho ─────────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.bar_chart_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Usuários — Dados Reais',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulseDot(color: AppColors.primary),
                  const SizedBox(width: 4),
                  const Text(
                    'AO VIVO',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Botão refresh manual
            IconButton(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh,
                  color: AppColors.textSecondary, size: 18),
              tooltip: 'Atualizar agora',
            ),
          ],
        ),
        // Última atualização
        if (_lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4, left: 2),
            child: Text(
              'Atualizado às ${_fmtTime(_lastUpdated)} · Próxima em 30s',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        const SizedBox(height: 12),
        // ── Error ─────────────────────────────────────────────────
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        // ── Cards ─────────────────────────────────────────────────
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              label: 'Cadastrados',
              value: _loading ? null : _total,
              icon: Icons.people_outline,
              color: AppColors.primary,
              subtitle: 'Total de contas criadas',
            ),
            _StatCard(
              label: 'Ativos agora',
              value: _loading ? null : _active,
              icon: Icons.bolt,
              color: const Color(0xFF22C55E),
              subtitle: 'Últimos $_activeThresholdMinutes minutos',
              pulseColor: const Color(0xFF22C55E),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Card individual ──────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final Color? pulseColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.pulseColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (pulseColor != null) _PulseDot(color: pulseColor!),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: value == null
                ? SizedBox(
                    key: const ValueKey('loading'),
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color),
                      ),
                    ),
                  )
                : Text(
                    key: ValueKey(value),
                    '$value',
                    style: TextStyle(
                      color: color,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Ponto pulsante animado ───────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
