import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class AdminEntityCard extends StatelessWidget {
  final String title;
  final String description;
  final Color colorType;
  final String badgeText;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const AdminEntityCard({
    super.key,
    required this.title,
    required this.description,
    required this.colorType,
    required this.badgeText,
    required this.isActive,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? colorType : AppColors.cardBorder.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: colorType.withValues(alpha: 0.2), blurRadius: 8)]
              : [],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: onDelete != null ? 32.0 : 0),
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isActive ? colorType : Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: colorType.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(badgeText, style: TextStyle(color: colorType, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (onDelete != null)
              Positioned(
                top: -8,
                right: -8,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () {
                    // Previne que o clique no deletar selecione o card
                    onDelete!();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Cards da Timeline (Learning Path)
class PathNodeCard extends StatelessWidget {
  final String title;
  final String type;
  final IconData icon;
  final bool isFirst;

  const PathNodeCard({super.key, required this.title, required this.type, required this.icon, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5), width: 4),
            ),
            child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: isFirst ? AppColors.warning : AppColors.textMuted, shape: BoxShape.circle))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.1))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4)),
                    child: Text(type, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuizNodeCard extends StatelessWidget {
  final String title;
  final int questionCount;

  const QuizNodeCard({super.key, required this.title, required this.questionCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5), width: 4),
            ),
            child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: AppColors.error, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.quiz, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(title, style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$questionCount Questões configuradas.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('+ Adicionar/Editar Questões', style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}