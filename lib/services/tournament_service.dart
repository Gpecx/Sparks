/// Manages weekly tournament logic with reset scheduling and prize distribution.
class TournamentService {
  static final TournamentService _instance = TournamentService._internal();
  factory TournamentService() => _instance;
  TournamentService._internal();

  /// Mock weekly tournament data.
  final List<TournamentPlayer> _weeklyRanking = [
    const TournamentPlayer(name: 'Maria Silva', xp: 2400, rank: 1),
    const TournamentPlayer(name: 'João Pedro', xp: 2150, rank: 2),
    const TournamentPlayer(name: 'Ana Costa', xp: 1800, rank: 3),
    const TournamentPlayer(name: 'Carlos R.', xp: 1650, rank: 4),
    const TournamentPlayer(name: 'Fernanda L.', xp: 1400, rank: 5),
    const TournamentPlayer(name: 'Bruno S.', xp: 1200, rank: 6),
    const TournamentPlayer(name: 'Patrícia M.', xp: 1050, rank: 7),
    const TournamentPlayer(name: 'Ricardo F.', xp: 900, rank: 8),
    const TournamentPlayer(name: 'Juliana B.', xp: 750, rank: 9),
    const TournamentPlayer(name: 'Diego O.', xp: 600, rank: 10),
    const TournamentPlayer(name: 'Camila N.', xp: 520, rank: 11),
    const TournamentPlayer(name: 'Você', xp: 480, rank: 12, isUser: true),
  ];

  List<TournamentPlayer> get weeklyRanking => List.unmodifiable(_weeklyRanking);

  /// Returns the XP prize for a given rank position.
  static int prizeForRank(int rank) {
    switch (rank) {
      case 1: return 500;
      case 2: return 300;
      case 3: return 150;
      default: return 0;
    }
  }

  /// Tournament status info.
  String get tournamentName => 'Competição Semanal';
  
  int get daysRemaining {
    final now = DateTime.now();
    // Ends on Sunday (weekday 7)
    return 7 - now.weekday;
  }

  String get endsLabel => daysRemaining == 0 ? 'Encerra hoje!' : 'Encerra em $daysRemaining dia${daysRemaining > 1 ? 's' : ''}';

  bool get isActive => true;
}

class TournamentPlayer {
  final String name;
  final int xp;
  final int rank;
  final bool isUser;

  const TournamentPlayer({
    required this.name,
    required this.xp,
    required this.rank,
    this.isUser = false,
  });
}
