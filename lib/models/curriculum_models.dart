import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
//  MODELOS DO CURRÍCULO
// ─────────────────────────────────────────────────────────────────

/// Uma micro-lição dentro de um módulo.
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

/// Um módulo de aprendizado dentro de uma categoria.
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

/// Uma categoria temática que agrupa módulos.
class LearningCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color gradientEnd;
  final List<LearningModule> modules;

  const LearningCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientEnd,
    required this.modules,
  });
}

// ─────────────────────────────────────────────────────────────────
//  DADOS MOCK DO CURRÍCULO
// ─────────────────────────────────────────────────────────────────

List<MicroLesson> _generateLessons(int count, String prefix) {
  final list = <MicroLesson>[];
  list.add(MicroLesson(id: '${prefix}_intro', title: 'Introdução', subtitle: 'Introdução ao Módulo'));
  for (int i = 1; i <= count; i++) {
    list.add(MicroLesson(id: '${prefix}_l$i', title: 'Lição $i', subtitle: 'Módulo Base'));
  }
  list.add(MicroLesson(id: '${prefix}_eval', title: 'AVALIAÇÃO', subtitle: 'Certificado', type: 'eval'));
  return list;
}

final List<LearningCategory> mockCategories = [
  // ── 1. NORMAS ──────────────────────────────────────────
  LearningCategory(
    id: 'normas',
    title: 'Normas Regulamentadoras',
    subtitle: 'NR-10, NR-12, NR-33, NR-35 e mais',
    icon: Icons.gavel,
    color: const Color(0xFF00C402),
    gradientEnd: const Color(0xFF1D5F31),
    modules: [
      LearningModule(
        id: 'nr10',
        title: 'NR-10 · Eletricidade',
        subtitle: 'Segurança em instalações e serviços em eletricidade',
        icon: Icons.flash_on,
        color: const Color(0xFF00C402),
        progress: 0.75,
        lessons: _generateLessons(10, 'nr10'),
      ),
      LearningModule(
        id: 'nr12',
        title: 'NR-12 · Máquinas',
        subtitle: 'Segurança no trabalho com máquinas e equipamentos',
        icon: Icons.precision_manufacturing,
        color: const Color(0xFF1D5F31),
        isLocked: true,
        lessons: _generateLessons(8, 'nr12'),
      ),
      LearningModule(
        id: 'nr33',
        title: 'NR-33 · Espaço Confinado',
        subtitle: 'Trabalhos em espaços confinados',
        icon: Icons.door_back_door,
        color: const Color(0xFFB0BEC5),
        isLocked: true,
        lessons: _generateLessons(6, 'nr33'),
      ),
      LearningModule(
        id: 'nr35',
        title: 'NR-35 · Trabalho em Altura',
        subtitle: 'Segurança em trabalhos em altura',
        icon: Icons.height,
        color: const Color(0xFFFF9800),
        isLocked: true,
        lessons: _generateLessons(8, 'nr35'),
      ),
    ],
  ),

  // ── 2. SELETIVIDADE ────────────────────────────────────
  LearningCategory(
    id: 'seletividade',
    title: 'Seletividade',
    subtitle: 'Coordenação e proteção de circuitos',
    icon: Icons.account_tree,
    color: const Color(0xFF42A5F5),
    gradientEnd: const Color(0xFF0D47A1),
    modules: [
      LearningModule(
        id: 'sel_intro',
        title: 'Fundamentos de Seletividade',
        subtitle: 'Conceitos básicos de coordenação',
        icon: Icons.school,
        color: const Color(0xFF42A5F5),
        progress: 0.0,
        lessons: _generateLessons(8, 'sel_intro'),
      ),
      LearningModule(
        id: 'sel_curvas',
        title: 'Curvas de Atuação',
        subtitle: 'Análise de curvas tempo × corrente',
        icon: Icons.show_chart,
        color: const Color(0xFF1565C0),
        isLocked: true,
        lessons: _generateLessons(6, 'sel_curvas'),
      ),
      LearningModule(
        id: 'sel_disjuntores',
        title: 'Seletividade entre Disjuntores',
        subtitle: 'Coordenação MT e BT',
        icon: Icons.toggle_on,
        color: const Color(0xFF0D47A1),
        isLocked: true,
        lessons: _generateLessons(7, 'sel_disj'),
      ),
    ],
  ),

  // ── 3. SEGURANÇA BÁSICA ────────────────────────────────
  LearningCategory(
    id: 'seguranca',
    title: 'Segurança Básica',
    subtitle: 'EPIs, procedimentos e primeiros socorros',
    icon: Icons.security,
    color: const Color(0xFFFF9800),
    gradientEnd: const Color(0xFFE65100),
    modules: [
      LearningModule(
        id: 'seg_epis',
        title: 'EPIs e EPCs',
        subtitle: 'Equipamentos de proteção individual e coletiva',
        icon: Icons.health_and_safety,
        color: const Color(0xFFFF9800),
        progress: 0.0,
        lessons: _generateLessons(8, 'seg_epis'),
      ),
      LearningModule(
        id: 'seg_socorros',
        title: 'Primeiros Socorros',
        subtitle: 'Choque elétrico, queimaduras e RCP',
        icon: Icons.local_hospital,
        color: const Color(0xFFF44336),
        isLocked: true,
        lessons: _generateLessons(6, 'seg_soc'),
      ),
      LearningModule(
        id: 'seg_bloqueio',
        title: 'Bloqueio e Etiquetagem',
        subtitle: 'Procedimentos LOTO',
        icon: Icons.lock_outline,
        color: const Color(0xFFE65100),
        isLocked: true,
        lessons: _generateLessons(5, 'seg_loto'),
      ),
    ],
  ),

  // ── 4. BT — BAIXA TENSÃO ──────────────────────────────
  LearningCategory(
    id: 'bt',
    title: 'BT · Baixa Tensão',
    subtitle: 'Circuitos até 1000V CA / 1500V CC',
    icon: Icons.electrical_services,
    color: const Color(0xFF66BB6A),
    gradientEnd: const Color(0xFF2E7D32),
    modules: [
      LearningModule(
        id: 'bt_residencial',
        title: 'Instalações Residenciais',
        subtitle: 'NBR 5410, quadros e circuitos',
        icon: Icons.home,
        color: const Color(0xFF66BB6A),
        progress: 0.0,
        lessons: _generateLessons(10, 'bt_res'),
      ),
      LearningModule(
        id: 'bt_industrial',
        title: 'Instalações Industriais BT',
        subtitle: 'Painéis, CCMs e aterramento',
        icon: Icons.factory,
        color: const Color(0xFF2E7D32),
        isLocked: true,
        lessons: _generateLessons(8, 'bt_ind'),
      ),
    ],
  ),

  // ── 5. MT — MÉDIA TENSÃO ──────────────────────────────
  LearningCategory(
    id: 'mt',
    title: 'MT · Média Tensão',
    subtitle: 'Circuitos entre 1kV e 36,2kV',
    icon: Icons.bolt,
    color: const Color(0xFFAB47BC),
    gradientEnd: const Color(0xFF6A1B9A),
    modules: [
      LearningModule(
        id: 'mt_subest',
        title: 'Subestações de Média Tensão',
        subtitle: 'Projeto, montagem e comissionamento',
        icon: Icons.domain,
        color: const Color(0xFFAB47BC),
        progress: 0.0,
        lessons: _generateLessons(10, 'mt_sub'),
      ),
      LearningModule(
        id: 'mt_protecao',
        title: 'Proteção em MT',
        subtitle: 'Relés, TCs, TPs e esquemas',
        icon: Icons.shield,
        color: const Color(0xFF6A1B9A),
        isLocked: true,
        lessons: _generateLessons(8, 'mt_prot'),
      ),
    ],
  ),

  // ── 6. AT — ALTA TENSÃO ───────────────────────────────
  LearningCategory(
    id: 'at',
    title: 'AT · Alta Tensão',
    subtitle: 'Circuitos acima de 36,2kV',
    icon: Icons.flash_on,
    color: const Color(0xFFEF5350),
    gradientEnd: const Color(0xFFB71C1C),
    modules: [
      LearningModule(
        id: 'at_linhas',
        title: 'Linhas de Transmissão',
        subtitle: 'Projeto, manutenção e segurança',
        icon: Icons.cell_tower,
        color: const Color(0xFFEF5350),
        progress: 0.0,
        lessons: _generateLessons(10, 'at_lin'),
      ),
      LearningModule(
        id: 'at_manobras',
        title: 'Manobras em AT',
        subtitle: 'Procedimentos e sequências de manobra',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFB71C1C),
        isLocked: true,
        lessons: _generateLessons(8, 'at_man'),
      ),
    ],
  ),
];
