import 'package:spark_app/l10n/app_localizations.dart';
import 'dart:async';
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
import 'package:cached_network_image/cached_network_image.dart';

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
  List<ClanRankingEntry> _clanRankings = [];
  bool _loadingGlobal = true;
  bool _loadingClan = true;
  String? _errorGlobal;
  String? _errorClan;

  // Real-time stream do ranking global e de clãs
  StreamSubscription<QuerySnapshot>? _globalStream;
  StreamSubscription<QuerySnapshot>? _clanStream;

  // Paginação
  int _paginatedGlobalCount = 10;
  static const int _pageSize = 10;

  // Cache de fotos resolvidas a partir de public_profiles (uid → photoUrl).
  // Evita refazer leituras a cada atualização do stream de ranking.
  final Map<String, String?> _photoCache = {};

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _subscribeGlobal();
    _subscribeClans();
  }

  @override
  void dispose() {
    _globalStream?.cancel();
    _clanStream?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Real-time listener para o ranking global ─────────────────────
  void _subscribeGlobal() {
    final userService = ref.read(userServiceProvider);
    final weekKey = userService.currentWeekKey;

    _globalStream?.cancel();
    _globalStream = _db
        .collection('rankings')
        .doc('weekly')
        .collection(weekKey)
        .orderBy('weeklyXp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snap) {
        final data = snap.docs
            .map((doc) => RankingEntry.fromFirestore(doc))
            .where((e) => !kHiddenRankingUids.contains(e.uid))
            .toList();
        for (int i = 0; i < data.length; i++) {
          data[i].position = i + 1;
          // Aplica foto já em cache (pode estar mais atualizada que o ranking).
          final cached = _photoCache[data[i].uid];
          if (cached != null && cached.isNotEmpty) {
            data[i].photoUrl = cached;
          }
        }
        if (mounted) {
          setState(() {
            _globalPlayers = data;
            _loadingGlobal = false;
            _errorGlobal = null;
          });
        }
        _enrichMissingPhotos(data);
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

  // ── Enriquece fotos faltantes a partir de public_profiles ───────
  // A doc de ranking só grava photoUrl no momento do addXp, então quem
  // mudou (ou nunca tinha) a foto aparece sem avatar. public_profiles é
  // o espelho mantido atualizado pelo servidor — buscamos de lá apenas
  // os uids ainda não resolvidos e atualizamos a lista em memória.
  Future<void> _enrichMissingPhotos(List<RankingEntry> entries) async {
    final pending = entries
        .where((e) =>
            (e.photoUrl == null || e.photoUrl!.isEmpty) &&
            !_photoCache.containsKey(e.uid))
        .map((e) => e.uid)
        .toSet()
        .toList();
    if (pending.isEmpty) return;

    var didUpdate = false;
    await Future.wait(pending.map((uid) async {
      try {
        final doc = await _db.collection('public_profiles').doc(uid).get();
        final photo = doc.data()?['photoUrl'] as String?;
        _photoCache[uid] = photo; // marca como resolvido (mesmo se null)
        if (photo != null && photo.isNotEmpty) {
          for (final e in _globalPlayers) {
            if (e.uid == uid) e.photoUrl = photo;
          }
          didUpdate = true;
        }
      } catch (_) {
        _photoCache[uid] = null;
      }
    }));

    if (didUpdate && mounted) setState(() {});
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
    _subscribeClans();
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final userService = ref.watch(userServiceProvider);
    final myUid = userService.uid;

    final players = _selectedTab == 1
        ? _clanRankings
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
                                  : AppLocalizations.of(context)!.weeklyRankingTitle,
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
                                              onPressed: () => setState(() =>
                                                  _paginatedGlobalCount +=
                                                      _pageSize),
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

      avatar = player.photoUrl != null
          ? CachedNetworkImage(
              imageUrl: player.photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (c, u, e) => _defaultAvatar(AppColors.primary))
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
    if (_selectedTab == 0) {
      final isVisible = visiblePlayers.any((p) => p is RankingEntry && p.uid == myUid);
      if (isVisible) return const SizedBox.shrink();

      final myIndex = _globalPlayers.indexWhere((p) => p.uid == myUid);
      if (myIndex < 0) return const SizedBox.shrink();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('• • •', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 14)),
          ),
          _buildPlayerRow(_globalPlayers[myIndex], myUid, userService.clanId),
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
              colors: [AppColors.card, AppColors.background],
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
                  Text(AppLocalizations.of(context)!.tournamentInProgress,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
                    color: AppColors.textSecondary,
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
        Text(AppLocalizations.of(context)!.participantsLabel,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        // Usa dados globais reais no torneio também
        ..._globalPlayers.take(8).map((player) {
          final userService = ref.read(userServiceProvider);
          return _buildPlayerRow(player, userService.uid, userService.clanId);
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