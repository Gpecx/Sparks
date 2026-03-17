import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showingClan = false; // false = Global, true = Clã

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
    final players = _showingClan ? _clanPlayers : _globalPlayers;
    final topThree = players.take(3).toList();
    final rest = players.skip(3).toList();

    return SparksBackground(
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
                        _showingClan ? 'RANKING DO CLÃ' : 'RANKING SEMANAL',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
                      ),
                    ),
                    Container(
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
                      _tabBtn('🌎  Global', !_showingClan, () => setState(() => _showingClan = false)),
                      _tabBtn('🛡️  Meu Clã', _showingClan, () => setState(() => _showingClan = true)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                      _showingClan ? 'Membros do Clã' : 'Classificação Geral',
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
                  children: rest.map((p) => _buildRankRow(p.rank, p.name, p.points, p.isHighlighted)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
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
                child: Icon(Icons.person, color: AppColors.textMuted, size: isFirst ? 34 : 24),
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
            child: const Icon(Icons.person, color: AppColors.textMuted, size: 20),
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