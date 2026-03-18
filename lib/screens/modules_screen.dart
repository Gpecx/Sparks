import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/learning_path_screen.dart';

class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'MÓDULOS DISPONÍVEIS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildModuleCard(
                context,
                title: 'Módulo 1: Segurança Básica',
                subtitle: 'Introdução e NR-10',
                progress: 0.75, // mock progress
                icon: Icons.security,
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LearningPathScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildModuleCard(
                context,
                title: 'Módulo 2: Trabalhos e Riscos',
                subtitle: 'NR-35 e Prevenções',
                progress: 0.0,
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFF9800),
                isLocked: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conclua o Módulo 1 para desbloquear!'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildModuleCard(
                context,
                title: 'Módulo 3: Avançado',
                subtitle: 'Gestão de Crises',
                progress: 0.0,
                icon: Icons.shield,
                color: AppColors.accent,
                isLocked: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Módulo bloqueado.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, {
    required String title,
    required String subtitle,
    required double progress,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked ? AppColors.cardBorder : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: isLocked ? null : [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isLocked ? AppColors.inputBackground : color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLocked ? Icons.lock : icon,
                      color: isLocked ? AppColors.textMuted : color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isLocked ? AppColors.textMuted : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: isLocked ? 0.5 : 1.0),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isLocked ? 'Bloqueado' : '${(progress * 100).toInt()}% Concluído',
                    style: TextStyle(
                      color: isLocked ? AppColors.textMuted : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isLocked)
                    Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
                ],
              ),
              if (!isLocked) const SizedBox(height: 8),
              if (!isLocked)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.inputBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}