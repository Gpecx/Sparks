import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_card.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/models/badge_model.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:spark_app/l10n/app_localizations.dart';

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
            title: Text(
              AppLocalizations.of(context)!.achievementsTitle,
              style: const TextStyle(
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
              SparkCard(
                margin: const EdgeInsets.only(bottom: 20),
                highlighted: true,
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
                            AppLocalizations.of(context)!.achievementsUnlockedCount(unlockedCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context)!.ofTotalAvailable(total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                SparkCard(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  radius: AppRadius.lg,
                  highlighted: true,
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
                      Text(
                        AppLocalizations.of(context)!.noAchievementsYet,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.noAchievementsDesc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/categories'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: Text(AppLocalizations.of(context)!.startLearningButton, style: const TextStyle(fontWeight: FontWeight.w700)),
                      )
                    ],
                  ),
                )
              else ...[
                // ── Dynamic badges from Firestore ────────────────────
                _sectionTitle(AppLocalizations.of(context)!.dynamicBadges),
                _buildDynamicBadges(unlockedIds),
                const SizedBox(height: 8),

                _sectionTitle(AppLocalizations.of(context)!.dedicationPresence),
                _achievementGrid(context, [
                  _AchievementData(AppLocalizations.of(context)!.achStreak7Title, Icons.local_fire_department, AppLocalizations.of(context)!.achStreak7Desc,
                      unlockedIds.contains('streak_7')),
                  _AchievementData(AppLocalizations.of(context)!.achStreak30Title, Icons.whatshot, AppLocalizations.of(context)!.achStreak30Desc,
                      unlockedIds.contains('streak_30')),
                  _AchievementData(AppLocalizations.of(context)!.achEarlyBirdTitle, Icons.wb_twilight, AppLocalizations.of(context)!.achEarlyBirdDesc,
                      unlockedIds.contains('noturno')),
                  _AchievementData(AppLocalizations.of(context)!.achDedicatedTitle, Icons.calendar_month, AppLocalizations.of(context)!.achDedicatedDesc,
                      unlockedIds.contains('streak_100')),
                ]),

                _sectionTitle(AppLocalizations.of(context)!.achievementsPerformance),
                _achievementGrid(context, [
                  _AchievementData(AppLocalizations.of(context)!.achFirstEvalTitle, Icons.quiz_outlined, AppLocalizations.of(context)!.achFirstEvalDesc,
                      unlockedIds.contains('first_lesson')),
                  _AchievementData(AppLocalizations.of(context)!.achTopScoreTitle, Icons.star_outlined, AppLocalizations.of(context)!.achTopScoreDesc,
                      unlockedIds.contains('xp_1000')),
                  _AchievementData(AppLocalizations.of(context)!.achPerfectStreakTitle, Icons.military_tech, AppLocalizations.of(context)!.achPerfectStreakDesc,
                      unlockedIds.contains('sniper')),
                  _AchievementData(AppLocalizations.of(context)!.achUnbeatableTitle, Icons.workspace_premium, AppLocalizations.of(context)!.achUnbeatableDesc,
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
        return SparkCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          color: isUnlocked ? AppColors.primary.withValues(alpha: 0.06) : AppColors.card,
          borderColor: isUnlocked
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.cardBorder.withValues(alpha: 0.25),
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
                        Flexible(
                          child: Text(
                            badge.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnlocked ? Colors.white : AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
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
    return SparkCard(
      padding: const EdgeInsets.all(14),
      color: data.unlocked ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card,
      borderColor: data.unlocked
          ? AppColors.primary.withValues(alpha: 0.4)
          : AppColors.cardBorder.withValues(alpha: 0.25),
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