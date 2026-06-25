import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/core/utils/rank_utils.dart';
import 'package:spark_app/models/badge_model.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  PERFIL PÚBLICO — bottom sheet aberto ao tocar num jogador do
//  ranking. Lê o espelho public_profiles/{uid} (sem PII) e exibe
//  patente ELO, clã, streak e principais conquistas.
// ─────────────────────────────────────────────────────────────────

/// Abre o perfil público de [uid] num bottom sheet.
Future<void> showPublicProfileSheet(BuildContext context, String uid) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PublicProfileSheet(uid: uid),
  );
}

class PublicProfileSheet extends StatelessWidget {
  final String uid;
  const PublicProfileSheet({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(), databaseId: 'default');

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Stream (não .get()): o card reflete em tempo real qualquer mudança no
      // espelho público — ELO/patente após um duelo ou reset, streak, etc.
      child: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('public_profiles').doc(uid).snapshots(),
        builder: (context, snap) {
          Widget body;
          if (snap.connectionState == ConnectionState.waiting) {
            body = const SizedBox(
              height: 280,
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            );
          } else {
            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            body = data.isEmpty
                ? const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text('Perfil indisponível.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                : _content(context, data);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Alça
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(child: SingleChildScrollView(child: body)),
            ],
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> data) {
    final name = (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? data['displayName'] as String
        : 'Usuário';
    final photo = (data['photoUrl'] as String?) ?? '';
    final profession = (data['profession'] as String?) ?? '';
    final elo = (data['eloRating'] as num?)?.toInt() ?? 0;
    final level = (data['level'] as num?)?.toInt() ?? 1;
    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    final streak = (data['currentStreak'] as num?)?.toInt() ?? 0;
    final longestStreak = (data['longestStreak'] as num?)?.toInt() ?? 0;
    final clanName = (data['clanName'] as String?) ?? '';
    final unlockedIds = (data['unlockedBadgeIds'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};

    final patente = RankUtils.fromElo(elo);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho: avatar + nome + profissão ──
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: patente.color, width: 2),
                ),
                child: ClipOval(
                  child: photo.isNotEmpty
                      ? Image.network(
                          photo,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                          errorBuilder: (c, e, s) => _avatarFallback(),
                        )
                      : _avatarFallback(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                    if (profession.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        profession,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Estatísticas ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.insights,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Estatísticas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Stats: nível, streak, recorde ──
          Row(
            children: [
              Expanded(
                  child: _statBox('⭐', '$level', 'Nível',
                      AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statBox('🔥', '$streak', 'Streak',
                      AppColors.warningAmber)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statBox('🏅', '$longestStreak', 'Recorde',
                      AppColors.gold)),
            ],
          ),
          const SizedBox(height: 12),

          // ── XP total + clã ──
          Row(
            children: [
              Expanded(
                child: _infoChip(
                    Icons.bolt, '$xp XP', AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoChip(
                    Icons.shield,
                    clanName.isNotEmpty ? clanName : 'Sem clã',
                    clanName.isNotEmpty
                        ? AppColors.gold
                        : AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Patente ELO (PvP) ──
          _patenteCard(elo, patente),
          const SizedBox(height: 18),

          // ── Conquistas ──
          Row(
            children: [
              const Text('🏆',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'Conquistas (${BadgeRegistry.unlockedCount(unlockedIds)}/${BadgeRegistry.totalCount})',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _achievements(unlockedIds),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: AppColors.primary.withValues(alpha: 0.2),
        child: const Icon(Icons.person, color: AppColors.primary, size: 30),
      );

  // Card de patente com barra de progresso até a próxima.
  Widget _patenteCard(int elo, Patente p) {
    final hint = p.isMaster
        ? 'Patente do modo Duelo — máxima, topo do ranking.'
        : 'Patente do modo Duelo — faltam ${p.eloToNext} de ELO para a próxima.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(p.icon, color: p.color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.label,
                      style: TextStyle(
                          color: p.color,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                    Text('$elo de ELO',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Identifica claramente que esta patente/ELO é do modo Duelo (PvP).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.color.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sports_kabaddi, color: p.color, size: 13),
                    const SizedBox(width: 4),
                    Text('PvP',
                        style: TextStyle(
                            color: p.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            // Anima a transição do progresso quando o ELO muda em tempo real
            // (o StreamBuilder reconstrói com o novo valor e a barra desliza).
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: p.tierProgress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.background.withValues(alpha: 0.6),
                valueColor: AlwaysStoppedAnimation(p.color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(hint,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statBox(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _achievements(Set<String> unlockedIds) {
    final unlocked = BadgeRegistry.allBadges
        .where((b) => unlockedIds.contains(b.id))
        .toList();

    if (unlocked.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
        ),
        child: const Text('Nenhuma conquista ainda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: unlocked
          .map((b) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(b.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
