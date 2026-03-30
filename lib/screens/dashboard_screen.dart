import 'dart:ui'; // Adicionado para o efeito Glassmorphism (BackdropFilter)
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/main_shell_screen.dart';
import 'package:spark_app/screens/settings_screen.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/screens/technical_standards_screen.dart';
import 'package:spark_app/services/streak_service.dart';
import 'package:spark_app/services/covenant_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Variável para controlar o estado de loading (Skeleton)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simula uma requisição na API de 2 segundos para mostrar o efeito Shimmer
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // ============================================================
  // LÓGICA DE SAUDAÇÃO DINÂMICA
  // ============================================================
  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Bom dia';
    } else if (hour < 18) {
      return 'Boa tarde';
    } else {
      return 'Boa noite';
    }
  }

  // ============================================================
  // MENU DE PERFIL (BottomSheet com animações)
  // ============================================================
  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: const CircleAvatar(
                        backgroundColor: AppColors.surface,
                        child: Icon(Icons.person, color: AppColors.accent, size: 30),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alex Rodriguez',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'alex.rodriguez@spark.com',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Técnico Líder',
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 1),
              _buildProfileMenuItem(
                icon: Icons.person_outline,
                label: 'Meu Perfil',
                onTap: () {
                  Navigator.pop(ctx);
                  final shell = context.findAncestorStateOfType<MainShellScreenState>();
                  shell?.switchTab(3);
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.settings_outlined,
                label: 'Configurações',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.emoji_events_outlined,
                label: 'Minhas Conquistas',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()));
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.trending_up,
                label: 'Meu Progresso',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechnicalStandardsScreen()));
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.help_outline,
                label: 'Ajuda / Suporte',
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Central de Ajuda em breve!')),
                  );
                },
              ),
              Divider(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 1),
              const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                 child: Text('NOVAS MECÂNICAS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              _buildProfileMenuItem(
                icon: Icons.flash_on,
                label: 'Duelo de Faíscas (PvP)',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/duel');
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.precision_manufacturing,
                label: 'Lab. de Simulação de Erros',
                color: AppColors.gold,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/error-simulation');
                },
              ),
              Divider(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 1),
              _buildProfileMenuItem(
                icon: Icons.logout,
                label: 'Sair',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final itemColor = color ?? Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: itemColor.withValues(alpha: 0.8), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: itemColor.withValues(alpha: 0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CABEÇALHO DE SESSÃO COM BOTÃO "VER TODAS"
  // ============================================================
  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        _ResponsiveTapWidget(
          onTap: onSeeAll,
          child: const Row(
            children: [
              Text(
                'Ver todas',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NOVO: COMPONENTE DE HEADER EXTRAÍDO PARA LIMPAR O BUILD
  // ============================================================
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getDynamicGreeting()},',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const Text(
              'Alex!', // Nome do usuário
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        _ResponsiveTapWidget(
          onTap: _showProfileMenu,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Cabeçalho (Header limpo)
                  _buildHeader(),
                  const SizedBox(height: 32), // Mais respiro visual
                  
                  // 2. Foco Principal: Progresso e Próxima Lição agrupados
                  _buildGamificationCenter(),
                  const SizedBox(height: 16), // Espaço menor aqui para agrupar o contexto
                  
                  _ResponsiveTapWidget(
                    onTap: () {
                      final shell = context.findAncestorStateOfType<MainShellScreenState>();
                      shell?.switchTab(1);
                    },
                    child: _buildContinueLearningCard(),
                  ),
                  const SizedBox(height: 40), // Espaço grande para separar seções
                  
                  // 3. Pactos Semanais (Gamificação e Engajamento)
                  _buildSectionHeader('Pactos Semanais', () {
                    context.push('/covenants');
                  }),
                  const SizedBox(height: 16),
                  _isLoading ? _buildCovenantSkeleton() : _buildCovenantList(),
                  const SizedBox(height: 40),

                  // 4. Normas em Destaque (Exploração - Agora com Glassmorphism)
                  _buildSectionHeader('Normas em Destaque', () {
                    context.push('/standards');
                  }),
                  const SizedBox(height: 16),
                  _isLoading ? _buildNormasSkeleton() : _buildNormasList(context),
                  const SizedBox(height: 40),
                  
                  // 5. Extras: Destaque de Segurança e Powerplay
                  _buildSecurityHighlightCard(),
                  const SizedBox(height: 24),
                  _buildPowerplayBanner(),
                  const SizedBox(height: 40), // Espaço extra no final da rolagem
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WIDGETS DE SKELETON (SHIMMER)
  // ============================================================
  Widget _buildCovenantSkeleton() {
    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: 2, 
        separatorBuilder: (ctx, index) => const SizedBox(width: 16),
        itemBuilder: (ctx, index) => const _SkeletonBox(width: 280, height: 145),
      ),
    );
  }

  Widget _buildNormasSkeleton() {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: 3,
        separatorBuilder: (ctx, index) => const SizedBox(width: 16),
        itemBuilder: (ctx, index) => const _SkeletonBox(width: 140, height: 140),
      ),
    );
  }

  // ============================================================
  // COMPONENTES EXISTENTES REVISADOS
  // ============================================================

  Widget _buildGamificationCenter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        // Deixei a borda um pouquinho mais suave para não poluir
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seu Progresso',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Técnico Nível 12',
                    style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              _ResponsiveTapWidget(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔥 Streak de ${StreakService().currentStreak} dias! Multiplicador de ${StreakService().xpMultiplier}x.'),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: AppColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${StreakService().currentStreak} Dias',
                        style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.cardBorder, height: 1),
          ),
          _ResponsiveTapWidget(
            onTap: () => _showDailyChallengeModal(context),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Desafio Diário',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'NR-10 • Revisão Rápida',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('+50 XP', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityHighlightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B1A), Color(0xFF061629)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF0D3B1A).withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.security, color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destaque de Segurança',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Confira as novas diretrizes da NR-10 e mantenha-se atualizado.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                _ResponsiveTapWidget(
                  onTap: () => context.push('/standards'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Acessar agora',
                      style: TextStyle(
                        color: AppColors.background,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        // Suavizamos a borda para integrar melhor ao gamification center
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue Aprendendo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16, // Reduzido para encaixar na nova hierarquia
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C402).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book, color: Color(0xFF00C402)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NR-35 Trabalho em Altura',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Módulo 3: Equipamentos de Proteção',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.65,
                    backgroundColor: AppColors.inputBackground,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '65%',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDailyChallengeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5))),
        title: Row(
          children: [
            const Icon(Icons.timer, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('Desafio Diário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teste seus conhecimentos em NR-10! Complete 3 perguntas rápidas para receber recompensas.', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [Text('💰 +50 XP', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)), Text('Recompensa', style: TextStyle(color: AppColors.textMuted, fontSize: 10))]),
                  Column(children: [Text('⏱️ 3 min', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)), Text('Tempo Est.', style: TextStyle(color: AppColors.textMuted, fontSize: 10))]),
                ],
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('AGORA NÃO', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iniciando desafio diário...'), backgroundColor: AppColors.primary));
            },
            child: const Text('INICIAR DESAFIO', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCovenantList() {
    final covenants = CovenantService().activeCovenants;
    
    return SizedBox(
      height: 145, 
      child: ListView.separated(
        scrollDirection: Axis.horizontal, 
        clipBehavior: Clip.none, 
        itemCount: covenants.length,
        separatorBuilder: (ctx, index) => const SizedBox(width: 16),
        itemBuilder: (ctx, index) {
          final cov = covenants[index];
          final progressPercent = cov.currentProgress / cov.maxProgress;
          
          return Container(
            width: 280, 
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cov.isCompleted ? AppColors.gold.withValues(alpha: 0.5) : AppColors.cardBorder.withValues(alpha: 0.5)),
              boxShadow: cov.isCompleted
                  ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1)]
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
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cov.title,
                          style: TextStyle(
                            color: cov.isCompleted ? AppColors.gold : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cov.reward,
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    cov.objective, 
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6, 
                        decoration: BoxDecoration(
                          color: AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progressPercent.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cov.isCompleted ? AppColors.gold : AppColors.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${cov.currentProgress}/${cov.maxProgress} ${cov.trackingType}',
                      style: TextStyle(
                        color: cov.isCompleted ? AppColors.gold : AppColors.textMuted,
                        fontSize: 11,
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

  Widget _buildNormasList(BuildContext context) {
    return SizedBox(
      height: 140, 
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 140, 
            child: _buildNormaCard(context, 'NR-10', 'Eletricidade', const Color(0xFF00C402))
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140, 
            child: _buildNormaCard(context, 'NR-12', 'Máquinas', const Color(0xFF1D5F31))
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140, 
            child: _buildNormaCard(context, 'NR-18', 'Construção', const Color(0xFF00C402))
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140, 
            child: _buildNormaCard(context, 'NR-33', 'Espaço Confinado', const Color(0xFFB0BEC5))
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOVO DESIGN DO CARD COM EFEITO DE VIDRO (GLASSMORPHISM)
  // ============================================================
  Widget _buildNormaCard(
      BuildContext context, String code, String name, Color iconColor) {
    return _ResponsiveTapWidget(
      onTap: () => context.push('/standards'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // O desfoque mágico aqui
          child: Container(
            decoration: BoxDecoration(
              // Cor semi-transparente para dar o efeito de vidro
              color: AppColors.card.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              // Borda bem sutil branca para destacar o vidro
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56, // Reduzido ligeiramente para mais respiro interno
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2), // Fundo suave para o ícone
                    shape: BoxShape.circle, // Círculo fica mais moderno aqui
                  ),
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPowerplayBanner() {
    return _ResponsiveTapWidget(
      onTap: () => context.push('/standard-detail'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF061629), Color(0xFF0D2641)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(
            color: const Color(0xFF00C402).withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C402).withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C402), Color(0xFF1D5F31)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C402).withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PowerPlay Streaming',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vídeos técnicos e conteúdos exclusivos para seu aprendizado',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C402), Color(0xFF1D5F31)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Saiba mais',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  WIDGET RESPONSIVO (escala + opacidade ao tocar)
// ─────────────────────────────────────────────────────────────────

class _ResponsiveTapWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ResponsiveTapWidget({required this.child, required this.onTap});

  @override
  State<_ResponsiveTapWidget> createState() => _ResponsiveTapWidgetState();
}

class _ResponsiveTapWidgetState extends State<_ResponsiveTapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  WIDGET DE ESQUELETO ANIMADO (SHIMMER NATIVO)
// ─────────────────────────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;

  const _SkeletonBox({required this.width, required this.height});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.8).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.cardBorder.withValues(alpha: 0.5), 
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}