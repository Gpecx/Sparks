import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/services/covenant_service.dart';

class CovenantsScreen extends StatefulWidget {
  const CovenantsScreen({super.key});

  @override
  State<CovenantsScreen> createState() => _CovenantsScreenState();
}

class _CovenantsScreenState extends State<CovenantsScreen> {
  @override
  Widget build(BuildContext context) {
    final covenants = CovenantService().activeCovenants;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Pactos Semanais',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: covenants.isEmpty
          ? Center(
              child: Text(
                'Nenhum pacto ativo no momento.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: covenants.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final cov = covenants[index];
                final progressPercent = cov.currentProgress / cov.maxProgress;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cov.isCompleted 
                          ? AppColors.gold.withValues(alpha: 0.5) 
                          : AppColors.cardBorder.withValues(alpha: 0.5),
                    ),
                    boxShadow: cov.isCompleted
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.1),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                cov.isCompleted ? Icons.check_circle : Icons.commit,
                                color: cov.isCompleted ? AppColors.gold : AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                cov.title,
                                style: TextStyle(
                                  color: cov.isCompleted ? AppColors.gold : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              cov.reward,
                              style: TextStyle(
                                color: AppColors.primary, 
                                fontSize: 11, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        cov.objective, 
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 8, 
                              decoration: BoxDecoration(
                                color: AppColors.cardBorder,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progressPercent.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cov.isCompleted ? AppColors.gold : AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${cov.currentProgress}/${cov.maxProgress} ${cov.trackingType}',
                            style: TextStyle(
                              color: cov.isCompleted ? AppColors.gold : AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }
}
