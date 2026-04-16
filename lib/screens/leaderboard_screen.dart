import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/services/tournament_service.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─────────────────────────────────────────────────────────────────
//  LEADERBOARD SCREEN — Versão com Firebase
//  MUDANÇAS:
//  - Aba Global: busca ranking real do Firestore (weeklyXp)
//  - Aba Clã: filtra pelo clanId do usuário logado
//  - Aba Torneio: mantida como estava (TournamentService)
//  - Posição do usuário logado destacada em todas as listas
//  - Paginação com "Carregar mais" continua funcionando
// ─────────────────────────────────────────────────────────────────

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _selectedTab = 0; // 0 = Global, 1 = Clã, 2 = Torneio
  final _tournament = TournamentService();

  // Dados do Firebase
  List<RankingEntry> _globalPlayers = [];
  List<RankingEntry> _clanPlayers = [];
  bool _loadingGlobal = true;
  bool _loadingClan = true;
  String? _errorGlobal;
  String? _errorClan;

  // Paginação
  int _paginatedGlobalCount = 10;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _loadRankings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRankings() async {
    final userService = ref.read(userServiceProvider);
    await Future.wait([
      _loadGlobal(userService),
      _loadClan(userService),
    ]);
  }

  Future<void> _loadGlobal(UserService userService) async {
    setState(() {
      _loadingGlobal = true;
      _errorGlobal = null;
    });
    try {
      final data = await userService.getGlobalWeeklyRanking();
      // Atribui posições
      for (int i = 0; i < data.length; i++) {
        data[i].position = i + 1;
      }
      if (mounted) setState(() {
        _globalPlayers = data;
        _loadingGlobal = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _errorGlobal = 'Erro ao carregar ranking';
        _loadingGlobal = false;
      });
    }
  }

  Future<void> _loadClan(UserService userService) async {
    setState(() {
      _loadingClan = true;
      _errorClan = null;
    });
    try {
      final data = await userService.getClanWeeklyRanking();
      for (int i = 0; i < data.length; i++) {
        data[i].position = i + 1;
      }
      if (mounted) setState(() {
        _clanPlayers = data;
        _loadingClan = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _errorClan = 'Erro ao carregar ranking do clã';
        _loadingClan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userService = ref.watch(userServiceProvider);
    final myUid = userService.uid;

    final players = _selectedTab == 1
        ? _clanPlayers
        : _globalPlayers.take(_paginatedGlobalCount).toList();

    final topThree = players.take(3).toList();
    final rest = players.skip(3).toList();
    final canLoadMoreGlobal =
        _selectedTab == 0 && _paginatedGlobalCount < _globalPlayers.length;
    final isLoadingCurrent =
        _selectedTab == 0 ? _loadingGlobal : _loadingClan;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _MoleculeIcon(size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedTab == 2
                              ? 'TORNEIO SEMANAL'
                              : _selectedTab == 1
                                  ? 'RANKING DO CLÃ'
                                  : 'RANKING SEMANAL',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _showYearCalendar(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    color: AppColors.primary, size: 13),
                                SizedBox(width: 5),
                                Text('Esta semana',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Toggle Global / Clã / Torneio ─────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.cardBorder.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        _tabBtn('🌎 Global', _selectedTab == 0,
                            () => setState(() => _selectedTab = 0)),
                        _tabBtn('🛡️ Clã', _selectedTab == 1,
                            () => setState(() => _selectedTab = 1)),
                        _tabBtn('🏆 Torneio', _selectedTab == 2,
                            () => setState(() => _selectedTab = 2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Conteúdo ──────────────────────────────────────
                if (_selectedTab == 2)
                  Expanded(child: _buildTournamentView())
                else
                  Expanded(
                    child: isLoadingCurrent
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary))
                        : (_selectedTab == 0 && _errorGlobal != null) ||
                                (_selectedTab == 1 && _errorClan != null)
                            ? _buildErrorView()
                            : players.isEmpty
                                ? _buildEmptyView()
                                : RefreshIndicator(
                                    color: AppColors.primary,
                                    onRefresh: _loadRankings,
                                    child: ListView(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      children: [
                                        // Pódio
                                        SizedBox(
                                          height: 220,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (topThree.length > 1)
                                                _buildPodiumItem(
                                                    topThree[1],
                                                    2,
                                                    AppColors.greenDark,
                                                    120,
                                                    myUid),
                                              const SizedBox(width: 10),
                                              if (topThree.isNotEmpty)
                                                _buildPodiumItem(
                                                    topThree[0],
                                                    1,
                                                    AppColors.primary,
                                                    160,
                                                    myUid),
                                              const SizedBox(width: 10),
                                              if (topThree.length > 2)
                                                _buildPodiumItem(
                                                    topThree[2],
                                                    3,
                                                    const Color(0xFF5A9A6E),
                                                    100,
                                                    myUid),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        // Lista (posições 4+)
                                        ...rest.map((player) => _buildPlayerRow(
                                            player, myUid)),
                                        if (canLoadMoreGlobal)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            child: TextButton(
                                              onPressed: () => setState(() =>
                                                  _paginatedGlobalCount +=
                                                      _pageSize),
                                              child: const Text(
                                                  'Carregar mais',
                                                  style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ),
                                        // Minha posição fixada no fundo (se fora do top visível)
                                        _buildMyPositionFooter(
                                            players, myUid, userService),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Pódio ────────────────────────────────────────────────────────
  Widget _buildPodiumItem(
      RankingEntry player, int place, Color color, double height, String myUid) {
    final isMe = player.uid == myUid;
    final medal = place == 1 ? '🥇' : place == 2 ? '🥈' : '🥉';

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(medal, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isMe ? AppColors.gold : color, width: isMe ? 2.5 : 2),
            ),
            child: ClipOval(
              child: player.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: player.photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => _defaultAvatar(color))
                  : _defaultAvatar(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _shortName(player.displayName),
            style: TextStyle(
                color: isMe ? AppColors.gold : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${player.weeklyXp} XP',
            style:
                TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(top: BorderSide(color: color, width: 1.5)),
            ),
            child: Center(
              child: Text('#$place',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar(Color color) {
    return Container(
      color: color.withValues(alpha: 0.2),
      child: Icon(Icons.person, color: color, size: 24),
    );
  }

  // ── Linha de jogador (posições 4+) ──────────────────────────────
  Widget _buildPlayerRow(RankingEntry player, String myUid) {
    final isMe = player.uid == myUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isMe
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${player.position}',
              style: TextStyle(
                  color: isMe ? AppColors.primary : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isMe
                      ? AppColors.primary
                      : AppColors.cardBorder.withValues(alpha: 0.4)),
            ),
            child: ClipOval(
              child: player.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: player.photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) =>
                          _defaultAvatar(AppColors.primary))
                  : _defaultAvatar(AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${player.displayName} (Você)' : player.displayName,
                  style: TextStyle(
                      color: isMe ? AppColors.primary : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                if (player.clanName != null)
                  Text(player.clanName!,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${player.weeklyXp} XP',
            style: TextStyle(
                color: isMe ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Mostra a posição do usuário fixada no fundo se ele não estiver
  /// na lista visível.
  Widget _buildMyPositionFooter(
      List<RankingEntry> visiblePlayers, String myUid, UserService userService) {
    final isVisible = visiblePlayers.any((p) => p.uid == myUid);
    if (isVisible) return const SizedBox.shrink();

    // Encontra nos dados completos
    final allPlayers =
        _selectedTab == 0 ? _globalPlayers : _clanPlayers;
    final myIndex = allPlayers.indexWhere((p) => p.uid == myUid);
    if (myIndex < 0) return const SizedBox.shrink();

    final me = allPlayers[myIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('• • •',
              style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                  fontSize: 14)),
        ),
        _buildPlayerRow(me, myUid),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          const Text('Não foi possível carregar o ranking',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadRankings,
            child: const Text('Tentar novamente',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.leaderboard_outlined,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            _selectedTab == 1
                ? 'Seu clã ainda não tem membros no ranking'
                : 'Nenhum dado de ranking esta semana',
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Tab button ─────────────────────────────────────────────────
  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                  color: active ? Colors.white : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  // ── Torneio (mantido como original) ────────────────────────────
  Widget _buildTournamentView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D2641), Color(0xFF061629)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events,
                      color: AppColors.gold, size: 24),
                  const SizedBox(width: 8),
                  const Text('Torneio em andamento',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('AO VIVO',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Complete o máximo de lições esta semana para subir no ranking e ganhar recompensas exclusivas!',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _tournamentStat('🥇', '500 XP', '1º lugar'),
                  _tournamentStat('🥈', '250 XP', '2º lugar'),
                  _tournamentStat('🥉', '100 XP', '3º lugar'),
                ],
              ),
            ],
          ),
        ),
        const Text('PARTICIPANTES',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        // Usa dados globais reais no torneio também
        ..._globalPlayers.take(8).map((player) {
          final userService = ref.read(userServiceProvider);
          return _buildPlayerRow(player, userService.uid);
        }),
      ],
    );
  }

  Widget _tournamentStat(String emoji, String prize, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(prize,
            style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  void _showYearCalendar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape:
          const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Período do ranking',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              'O ranking semanal é resetado toda segunda-feira às 00:00.\nSeus pontos acumulados ficam no histórico.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _shortName(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0]} ${parts[1][0]}.';
    return name;
  }
}

// ── Ícone decorativo ─────────────────────────────────────────────
class _MoleculeIcon extends StatelessWidget {
  final double size;
  const _MoleculeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.hub_outlined, color: AppColors.primary, size: size);
  }
}