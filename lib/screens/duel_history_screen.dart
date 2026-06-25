import 'package:flutter/material.dart';
import 'package:spark_app/core/utils/rank_utils.dart';
import 'package:spark_app/models/match_models.dart';
import 'package:spark_app/services/match_service.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';

/// Histórico dos últimos duelos PvP do jogador (somente leitura).
class DuelHistoryScreen extends StatefulWidget {
  const DuelHistoryScreen({super.key});

  @override
  State<DuelHistoryScreen> createState() => _DuelHistoryScreenState();
}

class _DuelHistoryScreenState extends State<DuelHistoryScreen> {
  final _service = MatchService();
  late Future<List<DuelMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchDuelHistory();
  }

  Future<void> _reload() async {
    setState(() => _future = _service.fetchDuelHistory());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _service.uid;
    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'HISTÓRICO DE DUELOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontSize: 16,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<List<DuelMatch>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              if (snap.hasError) {
                return _StateMessage(
                  icon: Icons.cloud_off,
                  title: 'Não foi possível carregar',
                  subtitle: 'Verifique sua conexão e tente novamente.',
                  onRetry: _reload,
                );
              }
              final matches = snap.data ?? const [];
              if (matches.isEmpty) {
                return const _StateMessage(
                  icon: Icons.sports_kabaddi,
                  title: 'Nenhum duelo ainda',
                  subtitle: 'Jogue seu primeiro Duelo de Faíscas e ele '
                      'aparecerá aqui!',
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.card,
                onRefresh: _reload,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: matches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _DuelHistoryCard(match: matches[i], uid: uid),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DuelHistoryCard extends StatelessWidget {
  final DuelMatch match;
  final String uid;
  const _DuelHistoryCard({required this.match, required this.uid});

  @override
  Widget build(BuildContext context) {
    final result = match.resultFor(uid); // win | loss | draw
    final myScore = match.myTotal(uid).round();
    final oppScore = match.oppTotal(uid).round();
    final eloChange = match.myEloChange(uid);
    final oppName = match.oppName(uid);
    final oppPhoto = match.oppPhoto(uid);
    final oppPatente = RankUtils.fromElo(match.oppElo(uid));

    final (Color color, String label, IconData icon) = switch (result) {
      'win' => (AppColors.primary, 'VITÓRIA', Icons.emoji_events),
      'loss' => (AppColors.error, 'DERROTA', Icons.close),
      _ => (AppColors.textMuted, 'EMPATE', Icons.remove),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3)),
          right: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3)),
          bottom: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Avatar do oponente
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surface,
            backgroundImage: (oppPhoto != null && oppPhoto.isNotEmpty)
                ? NetworkImage(oppPhoto)
                : null,
            child: (oppPhoto == null || oppPhoto.isEmpty)
                ? const Icon(Icons.person, color: AppColors.textMuted, size: 24)
                : null,
          ),
          const SizedBox(width: 12),
          // Nome + patente + data
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oppName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(oppPatente.icon, color: oppPatente.color, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      oppPatente.label,
                      style: TextStyle(color: oppPatente.color, fontSize: 11),
                    ),
                    if (match.finishedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(match.finishedAt!),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Placar + resultado + ELO
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$myScore × $oppScore',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                eloChange >= 0 ? '+$eloChange ELO' : '$eloChange ELO',
                style: TextStyle(
                  color: eloChange > 0
                      ? AppColors.primary
                      : (eloChange < 0 ? AppColors.error : AppColors.textMuted),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onRetry;
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                label: const Text('Tentar de novo',
                    style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
