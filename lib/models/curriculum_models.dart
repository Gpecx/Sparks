import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
//  MODELOS DO CURRÍCULO
// ─────────────────────────────────────────────────────────────────

class MicroLesson {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'lesson' | 'eval'

  const MicroLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    this.type = 'lesson',
  });
}

class LearningModule {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;
  final bool isLocked;
  final List<MicroLesson> lessons;

  const LearningModule({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.progress = 0.0,
    this.isLocked = false,
    this.lessons = const [],
  });
}

/// Categoria temática. [isLocked] bloqueia toda a categoria na tela inicial.
class LearningCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color gradientEnd;
  final bool isLocked;
  final List<LearningModule> modules;

  const LearningCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientEnd,
    this.isLocked = false,
    required this.modules,
  });
}

// ─────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────

List<MicroLesson> _buildLessons(String prefix, int count, int evalCount) {
  final list = <MicroLesson>[];
  for (int i = 1; i <= count; i++) {
    list.add(MicroLesson(
      id: '${prefix}_l$i',
      title: 'Lição $i',
      subtitle: 'Conteúdo didático',
    ));
  }
  for (int e = 1; e <= evalCount; e++) {
    list.add(MicroLesson(
      id: '${prefix}_eval$e',
      title: 'Avaliação $e',
      subtitle: 'Teste de conhecimentos',
      type: 'eval',
    ));
  }
  return list;
}

// ─────────────────────────────────────────────────────────────────
//  DADOS — 3 CATEGORIAS
// ─────────────────────────────────────────────────────────────────

final List<LearningCategory> mockCategories = [
  // ── 1. CAPACITAÇÃO TÉCNICA ── DISPONÍVEL ──────────────────────
  LearningCategory(
    id: 'capacitacao_tecnica',
    title: 'Capacitação Técnica',
    subtitle: '18 módulos · IEEE 1547, Proteções e Transdutores',
    icon: Icons.bolt,
    color: const Color(0xFFFFC107),
    gradientEnd: const Color(0xFFFF6F00),
    isLocked: false,
    modules: [
      // ── BLOCO 1: Fundamentos e Base Técnica ──────────────────
      LearningModule(
        id: 'mod01_fundamentos',
        title: 'Módulo 01 · Fundamentos Analíticos',
        subtitle: 'Sistema Por Unidade (PU) e Componentes Simétricas',
        icon: Icons.functions,
        color: const Color(0xFFFFC107),
        progress: 0.0,
        isLocked: false,
        lessons: _buildLessons('mod01', 20, 4),
      ),
      LearningModule(
        id: 'mod02_filosofia',
        title: 'Módulo 02 · Filosofia de Proteção',
        subtitle: 'Zonas de proteção e critérios de seletividade',
        icon: Icons.shield_outlined,
        color: const Color(0xFFFF8F00),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod02', 12, 2),
      ),
      LearningModule(
        id: 'mod03_linhas',
        title: 'Módulo 03 · Proteção de Linhas (LT)',
        subtitle: 'Proteção de distância, zonas Mho e Quadrilateral',
        icon: Icons.timeline,
        color: const Color(0xFFFF6F00),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod03', 16, 3),
      ),

      // ── BLOCO 2: Proteções Unitárias ─────────────────────────
      LearningModule(
        id: 'mod04',
        title: 'Módulo 04 · Proteção Diferencial',
        subtitle: 'Relés diferenciais e princípio de operação',
        icon: Icons.compare_arrows,
        color: const Color(0xFF42A5F5),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod04', 14, 3),
      ),
      LearningModule(
        id: 'mod05',
        title: 'Módulo 05 · Proteção de Distância',
        subtitle: 'Zonas de proteção e características de atuação',
        icon: Icons.social_distance,
        color: const Color(0xFF1E88E5),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod05', 16, 3),
      ),
      LearningModule(
        id: 'mod06',
        title: 'Módulo 06 · Sobrecorrente',
        subtitle: 'Relés de sobrecorrente: tempo definido e inverso',
        icon: Icons.flash_on,
        color: const Color(0xFF1565C0),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod06', 14, 2),
      ),

      // ── BLOCO 3: Proteções de Barramento e Equipamentos ──────
      LearningModule(
        id: 'mod07',
        title: 'Módulo 07 · Proteção de Barramento',
        subtitle: 'Esquemas de proteção de barras e zonas mortas',
        icon: Icons.account_tree,
        color: const Color(0xFF66BB6A),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod07', 12, 2),
      ),
      LearningModule(
        id: 'mod08',
        title: 'Módulo 08 · Proteção de Transformadores',
        subtitle: 'Diferenciais percentuais e proteções de backup',
        icon: Icons.electrical_services,
        color: const Color(0xFF43A047),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod08', 14, 3),
      ),
      LearningModule(
        id: 'mod09',
        title: 'Módulo 09 · Proteção de Geradores',
        subtitle: 'Funções 87G, 40, 46, 51V e esquemas de proteção',
        icon: Icons.energy_savings_leaf,
        color: const Color(0xFF2E7D32),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod09', 16, 3),
      ),

      // ── BLOCO 4: Sistemas de DER e Redes Inteligentes ────────
      LearningModule(
        id: 'mod10',
        title: 'Módulo 10 · DER e Fontes Renováveis',
        subtitle: 'Integração de geração distribuída ao sistema elétrico',
        icon: Icons.solar_power,
        color: const Color(0xFFAB47BC),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod10', 14, 2),
      ),
      LearningModule(
        id: 'mod11',
        title: 'Módulo 11 · Ilhamento e Anti-Ilhamento',
        subtitle: 'Detecção de ilhamento e requisitos IEEE 1547',
        icon: Icons.grid_off,
        color: const Color(0xFF8E24AA),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod11', 12, 2),
      ),
      LearningModule(
        id: 'mod12',
        title: 'Módulo 12 · Qualidade de Energia',
        subtitle: 'Harmônicos, flicker e desequilíbrio de tensão',
        icon: Icons.show_chart,
        color: const Color(0xFF6A1B9A),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod12', 14, 3),
      ),

      // ── BLOCO 5: Comunicação e Automação ─────────────────────
      LearningModule(
        id: 'mod13',
        title: 'Módulo 13 · Protocolo IEC 61850',
        subtitle: 'Comunicação em subestações digitais',
        icon: Icons.router,
        color: const Color(0xFFEF5350),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod13', 14, 2),
      ),
      LearningModule(
        id: 'mod14',
        title: 'Módulo 14 · Automação de Subestações',
        subtitle: 'SCADA, IED e arquitetura de automação',
        icon: Icons.settings_remote,
        color: const Color(0xFFE53935),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod14', 12, 2),
      ),
      LearningModule(
        id: 'mod15',
        title: 'Módulo 15 · Religadores e Seccionadores',
        subtitle: 'Automatização da rede de distribuição',
        icon: Icons.power,
        color: const Color(0xFFB71C1C),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod15', 12, 2),
      ),

      // ── BLOCO 6: Integração e Estudos Avançados ──────────────
      LearningModule(
        id: 'mod16',
        title: 'Módulo 16 · Estudos de Curto-Circuito',
        subtitle: 'Cálculo de correntes de falta e nível de curto',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF7043),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod16', 14, 3),
      ),
      LearningModule(
        id: 'mod17',
        title: 'Módulo 17 · Coordenação e Seletividade',
        subtitle: 'Curvas TCC e ajuste coordenado de proteções',
        icon: Icons.timeline,
        color: const Color(0xFFF4511E),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod17', 16, 3),
      ),
      LearningModule(
        id: 'mod18',
        title: 'Módulo 18 · Projeto Final Integrado',
        subtitle: 'Estudo de caso completo de proteção de sistema',
        icon: Icons.workspace_premium,
        color: const Color(0xFFBF360C),
        progress: 0.0,
        isLocked: true,
        lessons: _buildLessons('mod18', 10, 5),
      ),
    ],
  ),

  // ── 2. EQUIPAMENTOS SPCS ── BLOQUEADO ─────────────────────────
  LearningCategory(
    id: 'equipamentos_spcs',
    title: 'Equipamentos SPCS',
    subtitle: 'Em breve · Relés, IEDs e painéis SPCS',
    icon: Icons.memory,
    color: const Color(0xFF78909C),
    gradientEnd: const Color(0xFF37474F),
    isLocked: true,
    modules: [],
  ),

  // ── 3. NORMAS TÉCNICAS ── BLOQUEADO ───────────────────────────
  LearningCategory(
    id: 'normas_tecnicas',
    title: 'Normas Técnicas',
    subtitle: 'Em breve · ABNT, IEEE, IEC e NR',
    icon: Icons.gavel,
    color: const Color(0xFF78909C),
    gradientEnd: const Color(0xFF37474F),
    isLocked: true,
    modules: [],
  ),
];
