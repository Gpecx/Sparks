import 'package:spark_app/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_card.dart';
import 'package:spark_app/widgets/spark_skeleton.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────
//  LEADERBOARD SCREEN — Versão com Firebase
//  MUDANÇAS:
//  - Aba Global: busca ranking real do Firestore (weeklyXp)
//  - Aba Clã: exibe o ranking global de clãs
//  - Aba Torneio: mantida como estava (TournamentService)
//  - Posição do usuário/clã destacada em todas as listas
// ─────────────────────────────────────────────────────────────────

/// UIDs ocultados do ranking global (contas de desenvolvimento/teste que
/// distorcem a competição). Filtrados na leitura do ranking semanal.
const Set<String> kHiddenRankingUids = {
  'jhcX8vIPoUNs2JvhcxehFH5CR6y1', // Gabriel Chiarato Santana (programador)
  'bEROZ3kSCNanW9X4vTfqNI2Ugl02', // Fábio Souza — conta duplicada (menor); mantém só a de 483xp
};

class ClanRankingEntry {
  final String id;
  final String name;
  final int weeklyXp;
  final int iconCodePoint;
  final String primaryColor;
  int position;

  ClanRankingEntry({
    required this.id,
    required this.name,
    required this.weeklyXp,
    required this.iconCodePoint,
    required this.primaryColor,
    this.position = 0,
  });

  factory ClanRankingEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClanRankingEntry(
      id: doc.id,
      name: data['name'] ?? 'Clã',
      weeklyXp: (data['weeklyXp'] as num?)?.toInt() ?? 0,
      iconCodePoint: (data['iconCodePoint'] as num?)?.toInt() ?? Icons.shield.codePoint,
      primaryColor: data['primaryColor']?.toString() ?? '#FFD700',
    );
  }
}

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _selectedTab = 0; // 0 = Global, 1 = Clã, 2 = Torneio
  final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  // Dados do Firebase
  List<RankingEntry> _globalPlayers = [];
  List<RankingEntry> _tournamentPlayers = [];
  List<ClanRankingEntry> _clanRankings = [];
  bool _loadingGlobal = true;
  bool _loadingTournament = true;
  bool _loadingClan = true;
  String? _errorGlobal;
  String? _errorTournament;
  String? _errorClan;

  // Real-time stream do ranking global, torneio e de clãs
  StreamSubscription<QuerySnapshot>? _globalStream;
  StreamSubscription<QuerySnapshot>? _tournamentStream;
  StreamSubscription<QuerySnapshot>? _clanStream;

  // Evita reabrir o popup de vitória mais de uma vez por sessão.
  bool _tournamentRewardChecked = false;

  // Paginação
  int _paginatedGlobalCount = 10;
  int _paginatedTournamentCount = 10;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _subscribeGlobal();
    _subscribeTournament();
    _subscribeClans();
  }

  @override
  void dispose() {
    _globalStream?.cancel();
    _tournamentStream?.cancel();
    _clanStream?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Real-time listener para o RANKING GLOBAL (xp total, permanente) ──
  // Lê o espelho público (public_profiles), ordenado pelo XP acumulado.
  // Nunca zera nem apaga nomes.
  void _subscribeGlobal() {
    _globalStream?.cancel();
    _globalStream = _db
        .collection('public_profiles')
        .orderBy('xp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snap) {
        final data = snap.docs
            .map((doc) => RankingEntry.fromFirestore(doc, scoreField: 'xp'))
            // Só entra no ranking quem já ganhou algum XP (com scoreField:'xp'
            // o total de XP vem em weeklyXp) e esconde contas fantasma/duplicadas.
            .where((e) => e.weeklyXp > 0 && !kHiddenRankingUids.contains(e.uid))
            .toList();
        for (int i = 0; i < data.length; i++) {
          data[i].position = i + 1;
        }
        if (mounted) {
          setState(() {
            _globalPlayers = data;
            _loadingGlobal = false;
            _errorGlobal = null;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorGlobal = AppLocalizations.of(context)!.errorLoadingRanking;
            _loadingGlobal = false;
          });
        }
      },
    );
  }

  // ── Real-time listener para o TORNEIO (weeklyXp, reseta toda semana) ──
  // Também lê de public_profiles: as entradas/posições persistem, só o
  // weeklyXp é zerado pelo servidor (closeTournament) na virada da semana.
  void _subscribeTournament() {
    _tournamentStream?.cancel();
    _tournamentStream = _db
        .collection('public_profiles')
        .orderBy('weeklyXp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snap) {
        final data = snap.docs
            .map((doc) =>
                RankingEntry.fromFirestore(doc, scoreField: 'weeklyXp'))
            .where((e) => e.weeklyXp > 0)
            .toList();
        for (int i = 0; i < data.length; i++) {
          data[i].position = i + 1;
        }
        if (mounted) {
          setState(() {
            _tournamentPlayers = data;
            _loadingTournament = false;
            _errorTournament = null;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorTournament =
                AppLocalizations.of(context)!.errorLoadingRanking;
            _loadingTournament = false;
          });
        }
      },
    );
  }

  // ── Real-time listener para o ranking de clãs ───────────────────
  void _subscribeClans() {
    _clanStream?.cancel();
    _clanStream = _db
        .collection('clans')
        .orderBy('weeklyXp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snap) {
        final data = snap.docs
            .map((doc) => ClanRankingEntry.fromFirestore(doc))
            .toList();
        for (int i = 0; i < data.length; i++) {
          data[i].position = i + 1;
        }
        if (mounted) {
          setState(() {
            _clanRankings = data;
            _loadingClan = false;
            _errorClan = null;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorClan = AppLocalizations.of(context)!.errorLoadingClanRanking;
            _loadingClan = false;
          });
        }
      },
    );
  }

  // ── Refresh manual (pull-to-refresh) ─────────────────────────────
  Future<void> _loadRankings() async {
    _subscribeGlobal(); // reinicia o stream
    _subscribeTournament();
    _subscribeClans();
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final userService = ref.watch(userServiceProvider);
    final myUid = userService.uid;

    final List<dynamic> players = _selectedTab == 1
        ? _clanRankings
        : _selectedTab == 2
            ? _tournamentPlayers.take(_paginatedTournamentCount).toList()
            : _globalPlayers.take(_paginatedGlobalCount).toList();

    final topThree = players.take(3).toList();
    final rest = players.skip(3).toList();
    final canLoadMoreGlobal =
        (_selectedTab == 0 && _paginatedGlobalCount < _globalPlayers.length) ||
            (_selectedTab == 2 &&
                _paginatedTournamentCount < _tournamentPlayers.length);
    final isLoadingCurrent = _selectedTab == 0
        ? _loadingGlobal
        : _selectedTab == 2
            ? _loadingTournament
            : _loadingClan;
    final errorCurrent = _selectedTab == 0
        ? _errorGlobal
        : _selectedTab == 2
            ? _errorTournament
            : _errorClan;

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
                      if (Navigator.canPop(context))
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const _MoleculeIcon(size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedTab == 2
                              ? AppLocalizations.of(context)!.weeklyTournament
                              : _selectedTab == 1
                                  ? AppLocalizations.of(context)!.clanRankingTitle
                                  : AppLocalizations.of(context)!.globalRankingTitle,
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    color: AppColors.primary, size: 13),
                                const SizedBox(width: 5),
                                Text(AppLocalizations.of(context)!.thisWeek,
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
                            () => _selectTab(0)),
                        _tabBtn('🛡️ Clã', _selectedTab == 1,
                            () => _selectTab(1)),
                        _tabBtn('🏆 Torneio', _selectedTab == 2,
                            () => _selectTab(2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Conteúdo ──────────────────────────────────────
                Expanded(
                    child: isLoadingCurrent
                        ? ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              const SparkSkeleton(
                                  width: double.infinity, height: 200),
                              const SizedBox(height: 20),
                              ...List.generate(
                                6,
                                (_) => const SparkSkeleton(
                                  width: double.infinity,
                                  height: 56,
                                  radius: AppRadius.md,
                                  margin: EdgeInsets.only(bottom: 8),
                                ),
                              ),
                            ],
                          )
                        : errorCurrent != null
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
                                        // Card de premiação (só no Torneio)
                                        if (_selectedTab == 2)
                                          _buildTournamentPrizeCard(),
                                        // Pódio
                                        SizedBox(
                                          height: 310,
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
                                                    myUid,
                                                    userService.clanId),
                                              const SizedBox(width: 10),
                                              if (topThree.isNotEmpty)
                                                _buildPodiumItem(
                                                    topThree[0],
                                                    1,
                                                    AppColors.primary,
                                                    160,
                                                    myUid,
                                                    userService.clanId),
                                              const SizedBox(width: 10),
                                              if (topThree.length > 2)
                                                _buildPodiumItem(
                                                    topThree[2],
                                                    3,
                                                    const Color(0xFF5A9A6E),
                                                    100,
                                                    myUid,
                                                    userService.clanId),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        // Lista (posições 4+)
                                        ...rest.map((player) => _buildPlayerRow(
                                            player, myUid, userService.clanId)),
                                        if (canLoadMoreGlobal)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            child: TextButton(
                                              onPressed: () => setState(() {
                                                if (_selectedTab == 2) {
                                                  _paginatedTournamentCount +=
                                                      _pageSize;
                                                } else {
                                                  _paginatedGlobalCount +=
                                                      _pageSize;
                                                }
                                              }),
                                              child: Text(
                                                  AppLocalizations.of(context)!.loadMore,
                                                  style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w700)),
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
  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    return Color(int.parse(hexColor, radix: 16));
  }

  Widget _buildPodiumItem(
      dynamic player, int place, Color color, double height, String myUid, String? myClanId) {
    bool isMe = false;
    String photoUrl = '';
    String displayName = '';
    int weeklyXp = 0;
    Widget avatar;

    if (player is RankingEntry) {
      isMe = player.uid == myUid;
      photoUrl = player.photoUrl ?? '';
      displayName = player.displayName;
      weeklyXp = player.weeklyXp;
      
      avatar = photoUrl.isNotEmpty
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (c, e, s) => _defaultAvatar(color))
          : _defaultAvatar(color);
    } else if (player is ClanRankingEntry) {
      isMe = player.id == myClanId;
      displayName = player.name;
      weeklyXp = player.weeklyXp;
      
      final clanColor = _parseColor(player.primaryColor);
      avatar = Container(
        color: clanColor.withValues(alpha: 0.2),
        // ignore: non_const_argument_for_const_parameter — ícone dinâmico do clã (build usa --no-tree-shake-icons)
        child: Icon(IconData(player.iconCodePoint, fontFamily: 'MaterialIcons'), color: clanColor, size: 24),
      );
    } else {
      return const SizedBox();
    }

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
            child: ClipOval(child: avatar),
          ),
          const SizedBox(height: 6),
          Text(
            _shortName(displayName),
            style: TextStyle(
                color: isMe ? AppColors.gold : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$weeklyXp XP',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                      fontWeight: FontWeight.w800,
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
  Widget _buildPlayerRow(dynamic player, String myUid, String? myClanId) {
    bool isMe = false;
    String displayName = '';
    String? subName;
    int weeklyXp = 0;
    int position = 0;
    Widget avatar;

    if (player is RankingEntry) {
      isMe = player.uid == myUid;
      displayName = isMe ? '${player.displayName} (Você)' : player.displayName;
      subName = player.clanName;
      weeklyXp = player.weeklyXp;
      position = player.position;

      avatar = (player.photoUrl != null && player.photoUrl!.isNotEmpty)
          ? Image.network(
              player.photoUrl!,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (c, e, s) => _defaultAvatar(AppColors.primary))
          : _defaultAvatar(AppColors.primary);
    } else if (player is ClanRankingEntry) {
      isMe = player.id == myClanId;
      displayName = isMe ? '${player.name} (Seu Clã)' : player.name;
      weeklyXp = player.weeklyXp;
      position = player.position;

      final clanColor = _parseColor(player.primaryColor);
      avatar = Container(
        color: clanColor.withValues(alpha: 0.2),
        // ignore: non_const_argument_for_const_parameter — ícone dinâmico do clã (build usa --no-tree-shake-icons)
        child: Icon(IconData(player.iconCodePoint, fontFamily: 'MaterialIcons'), color: clanColor, size: 20),
      );
    } else {
      return const SizedBox();
    }

    return SparkCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: isMe
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.card,
      borderColor: isMe
          ? AppColors.primary.withValues(alpha: 0.4)
          : AppColors.cardBorder.withValues(alpha: 0.3),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$position',
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
            child: ClipOval(child: avatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isMe ? AppColors.primary : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                if (subName != null)
                  Text(subName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$weeklyXp XP',
            style: TextStyle(
                color: isMe ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Mostra a posição do usuário ou clã fixada no fundo se ele não estiver
  /// na lista visível.
  Widget _buildMyPositionFooter(
      List<dynamic> visiblePlayers, String myUid, UserService userService) {
    if (_selectedTab == 0 || _selectedTab == 2) {
      final source =
          _selectedTab == 2 ? _tournamentPlayers : _globalPlayers;
      final isVisible = visiblePlayers.any((p) => p is RankingEntry && p.uid == myUid);
      if (isVisible) return const SizedBox.shrink();

      final myIndex = source.indexWhere((p) => p.uid == myUid);
      if (myIndex < 0) return const SizedBox.shrink();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('• • •', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 14)),
          ),
          _buildPlayerRow(source[myIndex], myUid, userService.clanId),
        ],
      );
    } else if (_selectedTab == 1) {
      final myClanId = userService.clanId;
      if (myClanId == null) return const SizedBox.shrink();

      final isVisible = visiblePlayers.any((p) => p is ClanRankingEntry && p.id == myClanId);
      if (isVisible) return const SizedBox.shrink();

      final myIndex = _clanRankings.indexWhere((c) => c.id == myClanId);
      if (myIndex < 0) return const SizedBox.shrink();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('• • •', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 14)),
          ),
          _buildPlayerRow(_clanRankings[myIndex], myUid, userService.clanId),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.couldNotLoadRanking,
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadRankings,
            child: Text(AppLocalizations.of(context)!.tryAgain,
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
                ? AppLocalizations.of(context)!.noClansRankingWeek
                : _selectedTab == 2
                    ? AppLocalizations.of(context)!.noTournamentData
                    : AppLocalizations.of(context)!.noRankingDataWeek,
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
                      active ? FontWeight.w700 : FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ── Troca de aba; ao entrar no Torneio checa popup de vitória ────
  void _selectTab(int tab) {
    setState(() => _selectedTab = tab);
    if (tab == 2) _checkTournamentReward();
  }

  // ── Card de premiação do Torneio (header da lista) ──────────────
  Widget _buildTournamentPrizeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.card, AppColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.gold, size: 24),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.tournamentInProgress,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(AppLocalizations.of(context)!.liveLabel,
                    style: TextStyle(
                        color: AppColors.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.tournamentDescription,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tournamentStat('🥇', '500 XP',
                  AppLocalizations.of(context)!.firstPlaceShort),
              _tournamentStat('🥈', '250 XP',
                  AppLocalizations.of(context)!.secondPlaceShort),
              _tournamentStat('🥉', '100 XP',
                  AppLocalizations.of(context)!.thirdPlaceShort),
            ],
          ),
        ],
      ),
    );
  }

  // ── Popup de vitória do torneio ─────────────────────────────────
  // Lê a notificação `tournament_win` não lida (gravada pelo servidor em
  // closeTournament), exibe o popup animado e a marca como lida.
  Future<void> _checkTournamentReward() async {
    if (_tournamentRewardChecked) return;
    _tournamentRewardChecked = true;

    final uid = ref.read(userServiceProvider).uid;
    if (uid.isEmpty) return;

    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('type', isEqualTo: 'tournament_win')
          .where('read', isEqualTo: false)
          .limit(1)
          .get();
      if (snap.docs.isEmpty || !mounted) return;

      final doc = snap.docs.first;
      final data = doc.data();
      final place = (data['place'] as num?)?.toInt() ?? 0;
      final prize = (data['prize'] as num?)?.toInt() ?? 0;
      if (place < 1 || place > 3) return;

      // Marca como lida antes de exibir (cliente tem permissão na sua
      // subcoleção de notifications) — evita reabrir em outra sessão.
      await doc.reference.update({'read': true});

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.78),
        builder: (_) => TournamentWinDialog(place: place, prize: prize),
      );
    } catch (_) {
      // Falha silenciosa: o popup é cosmético, não bloqueia a tela.
    }
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
            Text(AppLocalizations.of(context)!.rankingPeriod,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.rankingResetInfo,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5),
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

// ─────────────────────────────────────────────────────────────────
//  POPUP ANIMADO DE VITÓRIA NO TORNEIO (1º / 2º / 3º lugar)
// ─────────────────────────────────────────────────────────────────
class TournamentWinDialog extends StatefulWidget {
  final int place; // 1, 2 ou 3
  final int prize; // XP premiado
  const TournamentWinDialog({
    super.key,
    required this.place,
    required this.prize,
  });

  @override
  State<TournamentWinDialog> createState() => _TournamentWinDialogState();
}

class _TournamentWinDialogState extends State<TournamentWinDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entry; // entrada (escala elástica)
  late final AnimationController _loop; // brilho + raios em loop

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750))
      ..forward();
    _loop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
  }

  @override
  void dispose() {
    _entry.dispose();
    _loop.dispose();
    super.dispose();
  }

  Color get _accent => widget.place == 1
      ? AppColors.gold
      : widget.place == 2
          ? const Color(0xFFC9D2DC) // prata
          : const Color(0xFFCD7F32); // bronze

  String get _medal =>
      widget.place == 1 ? '🥇' : widget.place == 2 ? '🥈' : '🥉';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scale = CurvedAnimation(parent: _entry, curve: Curves.elasticOut);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ScaleTransition(
        scale: scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Raios/partículas explodindo atrás do card.
            AnimatedBuilder(
              animation: _loop,
              builder: (_, _) => SizedBox(
                width: 320,
                height: 360,
                child: CustomPaint(
                  painter: _BurstPainter(
                      progress: _loop.value, color: _accent),
                ),
              ),
            ),
            // Card central.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.card, AppColors.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _accent.withValues(alpha: 0.6), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Medalha com brilho pulsante.
                  AnimatedBuilder(
                    animation: _loop,
                    builder: (_, child) {
                      final pulse =
                          0.9 + 0.12 * math.sin(_loop.value * 2 * math.pi);
                      return Transform.scale(scale: pulse, child: child);
                    },
                    child: Text(_medal, style: const TextStyle(fontSize: 76)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.tournamentWinTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.tournamentWinPlaceLine(widget.place),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: AppColors.gold, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          l.tournamentWinPrize(widget.prize),
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.tournamentWinSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l.tournamentWinClose,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Explosão de raios/partículas atrás do card de vitória.
class _BurstPainter extends CustomPainter {
  final double progress; // 0..1 (loop)
  final Color color;
  const _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const count = 14;
    final maxR = size.shortestSide * 0.62;

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      // Cada raio "pulsa" para fora com fase deslocada.
      final phase = (progress + i / count) % 1.0;
      final r = maxR * Curves.easeOut.transform(phase);
      final fade = (1.0 - phase);
      final p1 = Offset(
        center.dx + math.cos(angle) * (r * 0.45),
        center.dy + math.sin(angle) * (r * 0.45),
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      final paint = Paint()
        ..color = (i.isEven ? color : AppColors.primary)
            .withValues(alpha: 0.5 * fade)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
      // pontinho na ponta
      canvas.drawCircle(
        p2,
        2.5 * fade + 0.5,
        Paint()..color = color.withValues(alpha: 0.7 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.color != color;
}