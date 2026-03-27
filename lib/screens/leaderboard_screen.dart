import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/services/tournament_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _selectedTab = 0; // 0 = Global, 1 = Clã, 2 = Torneio
  final _tournament = TournamentService();

  int _paginatedGlobalCount = 5;

  // Mock de dados globais
  final List<_PlayerData> _globalPlayers = const [
    _PlayerData('John Doe', '12.500 XP', 1, true),
    _PlayerData('Jane S.', '8500 XP', 2, false),
    _PlayerData('Alice J.', '7200 XP', 3, false),
    _PlayerData('Bob Brown', '4500 XP', 4, false),
    _PlayerData('Charlie Davis', '4200 XP', 5, false),
    _PlayerData('Você', '3900 XP', 6, true),
    _PlayerData('Eva Green', '3500 XP', 7, false),
    _PlayerData('Frank White', '3100 XP', 8, false),
    _PlayerData('Sara Lima', '2800 XP', 9, false),
  ];

  // Mock de dados do clã
  final List<_PlayerData> _clanPlayers = const [
    _PlayerData('Alex Rodriguez', '14250 XP', 1, true),
    _PlayerData('Mariana Figueiredo', '12800 XP', 2, false),
    _PlayerData('Bruno Carvalho', '9400 XP', 3, false),
    _PlayerData('Camila Santos', '7600 XP', 4, false),
    _PlayerData('Diego Oliveira', '3200 XP', 5, false),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final players = _selectedTab == 1 ? _clanPlayers : _globalPlayers.take(_paginatedGlobalCount).toList();
    final topThree = players.take(3).toList();
    final rest = players.skip(3).toList();
    final canLoadMoreGlobal = _selectedTab == 0 && _paginatedGlobalCount < _globalPlayers.length;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _MoleculeIcon(size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedTab == 2 ? 'TORNEIO SEMANAL' : _selectedTab == 1 ? 'RANKING DO CLÃ' : 'RANKING SEMANAL',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _showYearCalendar(context),
                          child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 13),
                            SizedBox(width: 5),
                            Text('Esta semana', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Toggle Global / Clã
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        _tabBtn('🌎 Global', _selectedTab == 0, () => setState(() => _selectedTab = 0)),
                        _tabBtn('🛡️ Clã', _selectedTab == 1, () => setState(() => _selectedTab = 1)),
                        _tabBtn('🏆 Torneio', _selectedTab == 2, () => setState(() => _selectedTab = 2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Content area based on selected tab
                if (_selectedTab == 2)
                  Expanded(child: _buildTournamentView())
                else ...[
                  // Pódio
                  SizedBox(
                    height: 220,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (topThree.length > 1)
                          _buildPodiumItem(topThree[1].name, topThree[1].points, 2, AppColors.greenDark, 120),
                        const SizedBox(width: 10),
                        if (topThree.isNotEmpty)
                          _buildPodiumItem(topThree[0].name, topThree[0].points, 1, AppColors.primary, 160),
                        const SizedBox(width: 10),
                        if (topThree.length > 2)
                          _buildPodiumItem(topThree[2].name, topThree[2].points, 3, const Color(0xFF5A9A6E), 100),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Divisor
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _selectedTab == 1 ? 'Membros do Clã' : 'Classificação Geral',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, letterSpacing: 1),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.3))),
                    ]),
                  ),
                  const SizedBox(height: 10),

                  // Lista
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        ...rest.map((p) => _buildRankRow(p.rank, p.name, p.points, p.isHighlighted)),
                        if (canLoadMoreGlobal)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: TextButton(
                              onPressed: () => setState(() => _paginatedGlobalCount += 5),
                              child: const Text('Carregar Mais', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Calendário anual ─────────────────────────────────────────
  void _showYearCalendar(BuildContext context) {
    final now = DateTime.now();
    final year = now.year;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _YearCalendarPage(year: year, today: now),
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppColors.textMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumItem(String name, String points, int rank, Color color, double h) {
    final isFirst = rank == 1;
    final avatarSize = isFirst ? 76.0 : 60.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isFirst)
          Container(margin: const EdgeInsets.only(bottom: 6), child: const Icon(Icons.emoji_events, color: AppColors.gold, size: 26)),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: avatarSize, height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isFirst ? 3 : 2),
                boxShadow: isFirst ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 3)] : null,
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: 'https://i.pravatar.cc/150?u=${name.replaceAll(' ', '')}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) => Icon(Icons.person, color: AppColors.textMuted, size: isFirst ? 34 : 24),
                ),
              ),
            ),
            Positioned(
              bottom: -4,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 2)),
                child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(name, style: TextStyle(color: isFirst ? Colors.white : Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(points, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          width: isFirst ? 76 : 60,
          height: isFirst ? 36 : 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(child: Text('#$rank', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800))),
        ),
      ],
    );
  }

  Widget _buildRankRow(int rank, String name, String points, bool isYou) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isYou ? AppColors.primary.withValues(alpha: 0.10) : AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isYou ? AppColors.primary.withValues(alpha: 0.4) : AppColors.cardBorder.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$rank', style: TextStyle(color: isYou ? AppColors.primary : AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: AppColors.inputBackground, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: 'https://i.pravatar.cc/150?u=${name.replaceAll(' ', '')}',
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox(width: 14, height: 14, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (context, url, error) => const Icon(Icons.person, color: AppColors.textMuted, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: TextStyle(color: isYou ? Colors.white : Colors.white.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (isYou)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
              child: const Text('Você', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          Text(points, style: TextStyle(color: isYou ? AppColors.primary : AppColors.greenDark, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Tournament view ───────────────────────────────────────────
  Widget _buildTournamentView() {
    final players = _tournament.weeklyRanking;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Tournament info card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: AppColors.gold, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tournament.tournamentName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(_tournament.endsLabel, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Text('ATIVO', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Prizes
              Row(
                children: [
                  _prizeChip('🥇 1º', '500 XP', AppColors.gold),
                  const SizedBox(width: 8),
                  _prizeChip('🥈 2º', '300 XP', Colors.grey.shade400),
                  const SizedBox(width: 8),
                  _prizeChip('🥉 3º', '150 XP', const Color(0xFFCD7F32)),
                ],
              ),
            ],
          ),
        ),
        // Tournament ranking list
        ...players.map((p) {
          final isTop3 = p.rank <= 3;
          final medalEmoji = p.rank == 1 ? '🥇' : p.rank == 2 ? '🥈' : p.rank == 3 ? '🥉' : '';
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.isUser ? AppColors.primary.withValues(alpha: 0.10) : isTop3 ? AppColors.card : AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: p.isUser ? AppColors.primary.withValues(alpha: 0.4)
                    : isTop3 ? AppColors.gold.withValues(alpha: 0.2) : AppColors.cardBorder.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    isTop3 ? medalEmoji : '#${p.rank}',
                    style: TextStyle(fontSize: isTop3 ? 16 : 13, fontWeight: FontWeight.w800, color: p.isUser ? AppColors.primary : AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: AppColors.inputBackground, shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: 'https://i.pravatar.cc/150?u=${p.name.replaceAll(' ', '')}',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SizedBox(width: 12, height: 12, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    errorWidget: (context, url, error) => const Icon(Icons.person, color: AppColors.textMuted, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.name, style: TextStyle(color: p.isUser ? Colors.white : Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                if (p.isUser)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Você', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                Text('${p.xp} XP', style: TextStyle(color: p.isUser ? AppColors.primary : AppColors.greenDark, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _prizeChip(String label, String prize, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(prize, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PlayerData {
  final String name;
  final String points;
  final int rank;
  final bool isHighlighted;
  const _PlayerData(this.name, this.points, this.rank, this.isHighlighted);
}

class _MoleculeIcon extends StatelessWidget {
  final double size;
  const _MoleculeIcon({required this.size});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _MolPainter()));
  }
}

class _MolPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = const Color(0xFF00C402)..style = PaintingStyle.fill;
    final p2 = Paint()..color = const Color(0xFF1D5F31)..style = PaintingStyle.fill;
    final lp = Paint()..color = const Color(0xFF00C402).withValues(alpha: 0.5)..strokeWidth = 1..style = PaintingStyle.stroke;
    final cx = size.width / 2; final cy = size.height / 2; final r = size.width * 0.11;
    final pts = [Offset(cx, cy - size.height * 0.35), Offset(cx + size.width * 0.3, cy - size.height * 0.15),
      Offset(cx + size.width * 0.3, cy + size.height * 0.15), Offset(cx, cy + size.height * 0.35),
      Offset(cx - size.width * 0.3, cy + size.height * 0.15), Offset(cx - size.width * 0.3, cy - size.height * 0.15)];
    for (final pos in pts) canvas.drawLine(Offset(cx, cy), pos, lp);
    for (int i = 0; i < pts.length; i++) canvas.drawLine(pts[i], pts[(i + 1) % pts.length], lp);
    for (int i = 0; i < pts.length; i++) canvas.drawCircle(pts[i], r * 0.7, i.isEven ? p1 : p2);
    canvas.drawCircle(Offset(cx, cy), r * 1.1, p2);
    canvas.drawCircle(Offset(cx, cy), r * 0.75, p1);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// ─────────────────────────────────────────────────────────────────
//  PÁGINA DE CALENDÁRIO ANUAL
// ─────────────────────────────────────────────────────────────────

class _YearCalendarPage extends StatelessWidget {
  final int year;
  final DateTime today;

  const _YearCalendarPage({required this.year, required this.today});

  static const _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];
  static const _dayHeaders = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CALENDÁRIO $year',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          return _buildMonthCard(index + 1);
        },
      ),
    );
  }

  Widget _buildMonthCard(int month) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: 1=Mon ... 7=Sun. We want Mon=0 to Sun=6.
    final startWeekday = (firstDay.weekday - 1) % 7;
    final isCurrentMonth = today.year == year && today.month == month;

    // Compute current week range for highlighting
    final weekStart = today.subtract(Duration(days: (today.weekday - 1) % 7));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Container(
      decoration: BoxDecoration(
        color: isCurrentMonth ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentMonth ? AppColors.primary.withValues(alpha: 0.4) : AppColors.cardBorder.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month name
          Text(
            _monthNames[month - 1],
            style: TextStyle(
              color: isCurrentMonth ? AppColors.primary : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          // Day headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _dayHeaders.map((d) => SizedBox(
              width: 18,
              child: Text(d, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 8, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
          const SizedBox(height: 4),
          // Day grid
          Expanded(
            child: Column(
              children: _buildWeeks(month, daysInMonth, startWeekday, weekStart, weekEnd),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeks(int month, int daysInMonth, int startWeekday, DateTime weekStart, DateTime weekEnd) {
    final weeks = <Widget>[];
    int day = 1;

    for (int row = 0; row < 6 && day <= daysInMonth; row++) {
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        if (row == 0 && col < startWeekday || day > daysInMonth) {
          cells.add(const SizedBox(width: 18, height: 18));
        } else {
          final date = DateTime(year, month, day);
          final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
          final isThisWeek = !date.isBefore(weekStart) && !date.isAfter(weekEnd);

          cells.add(
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primary
                    : isThisWeek
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  color: isToday
                      ? Colors.white
                      : isThisWeek
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: isToday || isThisWeek ? FontWeight.w800 : FontWeight.normal,
                ),
              ),
            ),
          );
          day++;
        }
      }
      weeks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: cells),
        ),
      );
    }
    return weeks;
  }
}