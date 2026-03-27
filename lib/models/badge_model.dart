/// Contextual badge definitions and tracking logic.
class BadgeData {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final String criteria;
  final bool unlocked;
  final double progress; // 0.0 to 1.0

  const BadgeData({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.criteria,
    this.unlocked = false,
    this.progress = 0.0,
  });
}

/// All available dynamic contextual badges.
class BadgeRegistry {
  static const List<BadgeData> allBadges = [
    BadgeData(
      id: 'queimador',
      title: 'Queimador',
      emoji: '🔥',
      description: '5 quizzes acertados em 1 dia',
      criteria: 'Acertar 5 quizzes em um único dia',
      unlocked: true,
      progress: 1.0,
    ),
    BadgeData(
      id: 'sniper',
      title: 'Sniper',
      emoji: '🎯',
      description: '10 respostas corretas consecutivas',
      criteria: 'Responder 10 perguntas seguidas sem errar',
      unlocked: true,
      progress: 1.0,
    ),
    BadgeData(
      id: 'noturno',
      title: 'Noturno',
      emoji: '🌙',
      description: '3+ atividades entre 22h-6h',
      criteria: 'Completar 3 ou mais atividades entre 22:00 e 06:00',
      unlocked: false,
      progress: 0.33,
    ),
    BadgeData(
      id: 'top3',
      title: 'Top 3',
      emoji: '🏆',
      description: 'Estar no top 3 do leaderboard 3x',
      criteria: 'Estar no top 3 do ranking 3 vezes seguidas',
      unlocked: false,
      progress: 0.66,
    ),
    BadgeData(
      id: 'teorico',
      title: 'Teórico',
      emoji: '💡',
      description: 'Completar 50% de todas as normas',
      criteria: 'Completar pelo menos 50% dos módulos de todas as normas',
      unlocked: false,
      progress: 0.42,
    ),
    BadgeData(
      id: 'veloz',
      title: 'Veloz',
      emoji: '⚡',
      description: 'Responder quiz em <30s com acerto',
      criteria: 'Responder um quiz inteiro em menos de 30 segundos e acertar tudo',
      unlocked: false,
      progress: 0.0,
    ),
    BadgeData(
      id: 'cla_unido',
      title: 'Clã Unido',
      emoji: '🤝',
      description: 'Clã com 5+ membros ativos',
      criteria: 'Fazer parte de um clã com 5 ou mais membros ativos',
      unlocked: true,
      progress: 1.0,
    ),
  ];

  static int get unlockedCount => allBadges.where((b) => b.unlocked).length;
  static int get totalCount => allBadges.length;
}
