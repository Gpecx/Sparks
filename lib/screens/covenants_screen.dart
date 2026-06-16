import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/services/covenant_service.dart';
import 'package:spark_app/models/covenant_model.dart';
import 'package:spark_app/l10n/app_localizations.dart';

/// Displays all covenants: active (selected) and available to pick.
class CovenantsScreen extends StatefulWidget {
  const CovenantsScreen({super.key});

  @override
  State<CovenantsScreen> createState() => _CovenantsScreenState();
}

class _CovenantsScreenState extends State<CovenantsScreen> {
  final _service = CovenantService();
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle(CovenantModel cov) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      if (cov.isSelected) {
        await _service.deselectCovenant(cov.id);
      } else {
        await _service.selectCovenant(cov.id);
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _service.activeCovenants;
    final available = _service.availableCovenants;
    final l10n = AppLocalizations.of(context)!;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Text(
              l10n.covenantsTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.5),
            ),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // ── Info banner ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                      child: const Icon(Icons.commit, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.activeCovenantsCount(active.length),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.covenantsInfo,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Active covenants ───────────────────────────────────
              if (active.isNotEmpty) ...[
                _sectionTitle(l10n.myWeeklyCovenants),
                ...active.map((cov) => _CovenantCard(
                  covenant: cov,
                  onToggle: () => _toggle(cov),
                  toggling: _toggling,
                )),
                const SizedBox(height: 8),
              ],

              // ── Available covenants ────────────────────────────────
              if (available.isNotEmpty) ...[
                _sectionTitle(l10n.availableCovenantsTitle),
                ...available.map((cov) => _CovenantCard(
                  covenant: cov,
                  onToggle: () => _toggle(cov),
                  toggling: _toggling,
                )),
              ],

              if (active.isEmpty && available.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.loadingCovenants,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Text(
          t,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      );
}

/// Card for a single covenant, showing progress and a toggle button.
class _CovenantCard extends StatelessWidget {
  final CovenantModel covenant;
  final VoidCallback onToggle;
  final bool toggling;

  const _CovenantCard({
    required this.covenant,
    required this.onToggle,
    required this.toggling,
  });

  @override
  Widget build(BuildContext context) {
    final cov = covenant;
    final progressPercent = cov.maxProgress > 0
        ? (cov.currentProgress / cov.maxProgress).clamp(0.0, 1.0)
        : 0.0;
    final isCompleted = cov.isCompleted;
    final borderColor = isCompleted
        ? AppColors.gold.withValues(alpha: 0.5)
        : cov.isSelected
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.cardBorder.withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isCompleted
            ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.commit,
                color: isCompleted ? AppColors.gold : AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cov.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCompleted ? AppColors.gold : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      cov.objective,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Reward chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cov.reward,
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          if (cov.isSelected) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progressPercent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCompleted ? AppColors.gold : AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '${cov.currentProgress}/${cov.maxProgress} ${cov.trackingType}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCompleted ? AppColors.gold : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Toggle button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: toggling ? null : onToggle,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: cov.isSelected
                      ? AppColors.error.withValues(alpha: 0.6)
                      : AppColors.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: toggling
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(
                      cov.isSelected ? AppLocalizations.of(context)!.removeCovenantButton : AppLocalizations.of(context)!.selectCovenantButton,
                      style: TextStyle(
                        color: cov.isSelected ? AppColors.error : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
