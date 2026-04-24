/// Pure badge definition — no runtime state.
/// Unlocked state is determined by UserService.unlockedBadgeIds at runtime.
class BadgeData {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final String criteria;

  const BadgeData({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.criteria,
  });
}

/// Static catalog of all available dynamic contextual badges.
/// No unlocked/progress state here — resolved from Firestore at runtime.
class BadgeRegistry {
  static const List<BadgeData> allBadges = [
    BadgeData(
      id: 'queimador',
      title: 'Queimador',
      emoji: '🔥',
      description: '5 quizzes acertados em 1 dia',
      criteria: 'Acertar 5 quizzes em um único dia',
    ),
    BadgeData(
      id: 'sniper',
      title: 'Sniper',
      emoji: '🎯',
      description: '10 respostas corretas consecutivas',
      criteria: 'Responder 10 perguntas seguidas sem errar',
    ),
    BadgeData(
      id: 'noturno',
      title: 'Noturno',
      emoji: '🌙',
      description: '3+ atividades entre 22h-6h',
      criteria: 'Completar 3 ou mais atividades entre 22:00 e 06:00',
    ),
    BadgeData(
      id: 'top3',
      title: 'Top 3',
      emoji: '🏆',
      description: 'Estar no top 3 do leaderboard 3x',
      criteria: 'Estar no top 3 do ranking 3 vezes seguidas',
    ),
    BadgeData(
      id: 'teorico',
      title: 'Teórico',
      emoji: '💡',
      description: 'Completar 50% de todas as normas',
      criteria: 'Completar pelo menos 50% dos módulos de todas as normas',
    ),
    BadgeData(
      id: 'veloz',
      title: 'Veloz',
      emoji: '⚡',
      description: 'Responder quiz em <30s com acerto',
      criteria: 'Responder um quiz inteiro em menos de 30 segundos e acertar tudo',
    ),
    BadgeData(
      id: 'cla_unido',
      title: 'Clã Unido',
      emoji: '🤝',
      description: 'Clã com 5+ membros ativos',
      criteria: 'Fazer parte de um clã com 5 ou mais membros ativos',
    ),
    BadgeData(
      id: 'streak_3_days',
      title: 'Fogo Aceso',
      emoji: '🔥',
      description: 'Streak de 3 dias',
      criteria: 'Estudar 3 dias consecutivos',
    ),
    BadgeData(
      id: 'streak_7',
      title: 'Streak 7 dias',
      emoji: '📅',
      description: 'Estudou 7 dias consecutivos',
      criteria: 'Manter o streak por 7 dias',
    ),
    BadgeData(
      id: 'streak_30',
      title: 'Streak 30 dias',
      emoji: '🗓️',
      description: 'Estudou 30 dias consecutivos',
      criteria: 'Manter o streak por 30 dias',
    ),
    BadgeData(
      id: 'first_lesson',
      title: 'Primeira Aula',
      emoji: '🎓',
      description: 'Completou sua primeira lição',
      criteria: 'Completar 1 lição',
    ),
    BadgeData(
      id: 'lesson_10',
      title: '10 Lições',
      emoji: '📚',
      description: '10 lições concluídas',
      criteria: 'Completar 10 lições',
    ),
    BadgeData(
      id: 'lesson_50',
      title: 'Expert',
      emoji: '🥇',
      description: '50 lições concluídas',
      criteria: 'Completar 50 lições',
    ),
    BadgeData(
      id: 'xp_1000',
      title: '1.000 XP',
      emoji: '⭐',
      description: 'Atingiu 1.000 XP',
      criteria: 'Acumular 1.000 XP',
    ),
  ];

  /// Count of unlocked badges based on a set of unlocked IDs.
  static int unlockedCount(Set<String> unlockedIds) =>
      allBadges.where((b) => unlockedIds.contains(b.id)).length;

  static int get totalCount => allBadges.length;
}
