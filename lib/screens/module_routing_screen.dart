import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/providers/content_providers.dart';

import 'package:spark_app/screens/learning_path_screen.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/widgets/sparks_background.dart';

class ModuleRoutingScreen extends ConsumerWidget {
  final String categoryId;
  final String moduleId;

  const ModuleRoutingScreen({
    super.key,
    required this.categoryId,
    required this.moduleId,
  });

  static const List<Map<String, dynamic>> _themeConfig = [
    {'color': Color(0xFF00C402), 'icon': Icons.bolt},
    {'color': Color(0xFF22C55E), 'icon': Icons.memory},
    {'color': Color(0xFF2DD4BF), 'icon': Icons.gavel},
    {'color': Color(0xFF84CC16), 'icon': Icons.lightbulb},
    {'color': Color(0xFF4ADE80), 'icon': Icons.layers},
    {'color': Color(0xFF34D399), 'icon': Icons.science},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final modulesAsync = ref.watch(modulesStreamProvider(categoryId));

    return categoriesAsync.when(
      data: (categories) {
        return modulesAsync.when(
          data: (modules) {
            final categoryIndex = categories.indexWhere((c) => c.id == categoryId);
            if (categoryIndex == -1) {
              return _buildErrorScreen(context, 'Categoria não encontrada');
            }
            final category = categories[categoryIndex];

            final moduleIndex = modules.indexWhere((m) => m.id == moduleId);
            if (moduleIndex == -1) {
              return _buildErrorScreen(context, 'Módulo não encontrado');
            }
            final module = modules[moduleIndex];

            final theme = _themeConfig[categoryIndex % _themeConfig.length];
            final themeColor = theme['color'] as Color;
            final themeIcon = theme['icon'] as IconData;

            return LearningPathScreen(
              category: category,
              module: module,
              themeColor: themeColor,
              themeIcon: themeIcon,
            );
          },
          loading: () => _buildLoadingScreen(),
          error: (err, stack) => _buildErrorScreen(context, 'Erro ao carregar o módulo: $err'),
        );
      },
      loading: () => _buildLoadingScreen(),
      error: (err, stack) => _buildErrorScreen(context, 'Erro ao carregar categoria: $err'),
    );
  }

  Widget _buildLoadingScreen() {
    return const SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3.0,
                ),
                SizedBox(height: 16),
                Text(
                  'Carregando trilha...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String message) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ops! Ocorreu um problema',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Voltar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
