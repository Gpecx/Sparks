import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/models/badge_model.dart';
import 'package:spark_app/providers/user_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userService = ref.watch(userServiceProvider);
    final unlockedIds = userService.unlockedBadgeIds.toSet();
    final unlockedCount = BadgeRegistry.unlockedCount(unlockedIds);
    final total = BadgeRegistry.totalCount + 8; // +8 for static achievement cards
    final percent = total > 0 ? unlockedCount / total : 0.0;

    return SparksBackground(
      child: PcbBackground(
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
              'CONQUISTAS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // ── Summary card (reactive) ──────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events, color: AppColors.gold, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unlockedCount Conquistas',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'de $total disponíveis',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 60,
                        child: Column(
                          children: [
                            Text(
                              '${(percent * 100).round()}%',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percent.clamp(0.0, 1.0),
                              backgroundColor: AppColors.inputBackground,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              minHeight: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (unlockedCount == 0)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Icon(Icons.lock_outline, size: 40, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Nenhuma conquista ainda',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Complete lições, mantenha seu streak de ofensiva e gabarite os testes para destravar conquistas exclusivas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('COMEÇAR APRENDER', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              else ...[
                // ── Dynamic badges from Firestore ────────────────────
                _sectionTitle('BADGES DINÂMICAS'),
                _buildDynamicBadges(unlockedIds),
                const SizedBox(height: 8),

                _sectionTitle('NORMAS E CONHECIMENTO'),
                _achievementGrid(context, [
                  _AchievementData('Mestre NR-10', Icons.electrical_services, 'Completou todos os módulos da NR-10',
                      unlockedIds.contains('nr10_master')),
                  _AchievementData('Expert NFPA 70E', Icons.shield_outlined, 'Completou todos os módulos da NFPA 70E',
                      unlockedIds.contains('nfpa_expert')),
                  _AchievementData('Pro em Segurança', Icons.verified_outlined, 'Atingiu 95% de acerto em 5 avaliações',
                      unlockedIds.contains('safety_pro')),
                  _AchievementData('Mestre NR-35', Icons.height, 'Completou todos os módulos da NR-35',
                      unlockedIds.contains('nr35_master')),
                ]),

                _sectionTitle('DEDICAÇÃO E PRESENÇA'),
                _achievementGrid(context, [
                  _AchievementData('Streak 7 dias', Icons.local_fire_department, 'Estudou 7 dias consecutivos',
                      unlockedIds.contains('streak_7')),
                  _AchievementData('Streak 30 dias', Icons.whatshot, 'Estudou 30 dias consecutivos',
                      unlockedIds.contains('streak_30')),
                  _AchievementData('Madrugador', Icons.wb_twilight, 'Estudou antes das 7h por 5 dias',
                      unlockedIds.contains('noturno')),
                  _AchievementData('Dedicado', Icons.calendar_month, 'Ativo por 60 dias',
                      unlockedIds.contains('streak_100')),
                ]),

                _sectionTitle('PERFORMANCE'),
                _achievementGrid(context, [
                  _AchievementData('Primeira Avaliação', Icons.quiz_outlined, 'Completou sua primeira avaliação',
                      unlockedIds.contains('first_lesson')),
                  _AchievementData('Nota Máxima', Icons.star_outlined, 'Tirou 100% em uma avaliação',
                      unlockedIds.contains('xp_1000')),
                  _AchievementData('Sequência Perfeita', Icons.military_tech, '10 acertos seguidos no quiz',
                      unlockedIds.contains('sniper')),
                  _AchievementData('Imbatível', Icons.workspace_premium, 'Completou 5 avaliações com nota máxima',
                      unlockedIds.contains('lesson_50')),
                ]),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicBadges(Set<String> unlockedIds) {
    return Column(
      children: BadgeRegistry.allBadges.map((badge) {
        final isUnlocked = unlockedIds.contains(badge.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnlocked ? AppColors.primary.withValues(alpha: 0.06) : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnlocked
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.cardBorder.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.inputBackground,
                  border: Border.all(
                    color: isUnlocked
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.cardBorder.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(badge.emoji, style: TextStyle(fontSize: isUnlocked ? 22 : 18)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          badge.title,
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isUnlocked) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('✓', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      badge.description,
                      style: TextStyle(
                        color: isUnlocked ? AppColors.textSecondary : AppColors.textMuted.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isUnlocked)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.lock_outline, color: AppColors.textMuted, size: 16),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
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

  Widget _achievementGrid(BuildContext context, List<_AchievementData> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _AchievementCard(data: items[i]),
    );
  }
}

class _AchievementData {
  final String title;
  final IconData icon;
  final String description;
  final bool unlocked;
  const _AchievementData(this.title, this.icon, this.description, this.unlocked);
}

class _AchievementCard extends StatelessWidget {
  final _AchievementData data;
  const _AchievementCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data.unlocked ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: data.unlocked
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.cardBorder.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.unlocked
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.inputBackground,
                  border: Border.all(
                    color: data.unlocked
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : Colors.transparent,
                  ),
                ),
                child: Icon(
                  data.icon,
                  color: data.unlocked ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.4),
                  size: 26,
                ),
              ),
              if (!data.unlocked)
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(color: AppColors.inputBackground, shape: BoxShape.circle),
                  child: const Icon(Icons.lock, color: AppColors.textMuted, size: 10),
                ),
              if (data.unlocked)
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: Colors.white, size: 10),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: data.unlocked ? Colors.white : AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: data.unlocked
                  ? AppColors.textSecondary
                  : AppColors.textMuted.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}