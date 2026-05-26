import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/providers/progress_provider.dart';
import 'package:spark_app/models/progress_model.dart';
import 'package:spark_app/services/user_service.dart';

class MyProgressScreen extends ConsumerWidget {
  const MyProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(userProgressProvider);
    final user = UserService().user;
    final level = UserService().level;
    final totalXp = user?.xp ?? 0;

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
            title: const Text(
              'MEU PROGRESSO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
            centerTitle: true,
          ),
          body: progressAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(
              child: Text('Erro ao carregar progresso', style: const TextStyle(color: AppColors.error)),
            ),
            data: (list) => _buildBody(context, list, level, totalXp),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ProgressModel> list, int level, int totalXp) {
    final completed = list.where((p) => p.isCompleted).toList();
    final inProgress = list.where((p) => !p.isCompleted).toList()
      ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Resumo geral ──────────────────────────────────────────
          _buildSummaryCard(list, level, totalXp),
          const SizedBox(height: 28),

          if (list.isEmpty) ...[
            _buildEmptyState(context),
          ] else ...[
            // Em andamento
            if (inProgress.isNotEmpty) ...[
              _sectionTitle('EM ANDAMENTO', AppColors.primary),
              const SizedBox(height: 12),
              ...inProgress.map((p) => _buildProgressCard(p, false)),
              const SizedBox(height: 24),
            ],

            // Concluídos
            if (completed.isNotEmpty) ...[
              _sectionTitle('CONCLUÍDOS', AppColors.gold),
              const SizedBox(height: 12),
              ...completed.map((p) => _buildProgressCard(p, true)),
              const SizedBox(height: 24),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<ProgressModel> list, int level, int totalXp) {
    final totalModules = list.length;
    final completedCount = list.where((p) => p.isCompleted).length;
    final totalLessons = list.fold<int>(0, (sum, p) => sum + p.completedLessons.length);
    final avgProgress = list.isEmpty
        ? 0.0
        : list.fold<double>(0, (sum, p) => sum + p.progressPercent) / list.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nível atual', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      'Técnico Nível $level',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$totalXp XP',
                    style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const Text('total', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statChip(Icons.layers_outlined, '$totalModules', 'módulos', AppColors.blue),
              const SizedBox(width: 10),
              _statChip(Icons.check_circle_outline, '$completedCount', 'concluídos', AppColors.primary),
              const SizedBox(width: 10),
              _statChip(Icons.menu_book_outlined, '$totalLessons', 'lições', AppColors.gold),
            ],
          ),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: avgProgress.clamp(0.0, 1.0),
                      backgroundColor: AppColors.inputBackground,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(avgProgress * 100).toInt()}% médio',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(ProgressModel p, bool isCompleted) {
    final pct = (p.progressPercent * 100).toInt().clamp(0, 100);
    final color = isCompleted ? AppColors.gold : AppColors.primary;
    final name = p.moduleName.isNotEmpty ? p.moduleName : p.moduleId;
    final lastAccessed = _formatDate(p.lastAccessed);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isCompleted ? 0.4 : 0.2)),
        boxShadow: isCompleted
            ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.07), blurRadius: 8)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.menu_book,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isCompleted ? AppColors.gold : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.completedLessons.length} lição(ões) • Acessado $lastAccessed',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCompleted ? 'CONCLUÍDO' : '$pct%',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.progressPercent.clamp(0.0, 1.0),
                backgroundColor: AppColors.inputBackground,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.trending_up, color: AppColors.textMuted, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum progresso ainda',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete lições e módulos para acompanhar\nseu progresso aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => context.go('/categories'),
            icon: const Icon(Icons.play_arrow, color: AppColors.background),
            label: const Text(
              'COMEÇAR A APRENDER',
              style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      );

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'hoje';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
