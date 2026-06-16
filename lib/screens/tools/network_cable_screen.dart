import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

// Referência de cabeamento estruturado para redes SPCS:
// pinagem T568A/T568B (RJ-45) + tabela de categorias de cabo.

class _PinColor {
  final String name;
  final Color color;
  final bool striped; // par "branco/cor"
  const _PinColor(this.name, this.color, this.striped);
}

// T568B (o mais usado no Brasil/EUA)
const List<_PinColor> _t568b = [
  _PinColor('Branco/Laranja', Color(0xFFFF8A00), true),
  _PinColor('Laranja', Color(0xFFFF8A00), false),
  _PinColor('Branco/Verde', Color(0xFF2EAd4B), true),
  _PinColor('Azul', Color(0xFF2563EB), false),
  _PinColor('Branco/Azul', Color(0xFF2563EB), true),
  _PinColor('Verde', Color(0xFF2EAd4B), false),
  _PinColor('Branco/Marrom', Color(0xFF8B5A2B), true),
  _PinColor('Marrom', Color(0xFF8B5A2B), false),
];

// T568A (par verde e laranja trocados em relação ao B)
const List<_PinColor> _t568a = [
  _PinColor('Branco/Verde', Color(0xFF2EAd4B), true),
  _PinColor('Verde', Color(0xFF2EAd4B), false),
  _PinColor('Branco/Laranja', Color(0xFFFF8A00), true),
  _PinColor('Azul', Color(0xFF2563EB), false),
  _PinColor('Branco/Azul', Color(0xFF2563EB), true),
  _PinColor('Laranja', Color(0xFFFF8A00), false),
  _PinColor('Branco/Marrom', Color(0xFF8B5A2B), true),
  _PinColor('Marrom', Color(0xFF8B5A2B), false),
];

class _CableCat {
  final String cat;
  final String band;
  final String speed;
  final String length;
  const _CableCat(this.cat, this.band, this.speed, this.length);
}

const List<_CableCat> _categories = [
  _CableCat('Cat 5e', '100 MHz', '1 Gbps', '100 m'),
  _CableCat('Cat 6', '250 MHz', '1 Gbps (10G ≤ 55 m)', '100 m'),
  _CableCat('Cat 6A', '500 MHz', '10 Gbps', '100 m'),
  _CableCat('Cat 7', '600 MHz', '10 Gbps', '100 m'),
  _CableCat('Cat 7A', '1000 MHz', '10 Gbps', '100 m'),
  _CableCat('Cat 8', '2000 MHz', '25–40 Gbps', '30 m'),
];

class NetworkCableScreen extends StatelessWidget {
  const NetworkCableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(AppLocalizations.of(context)!.netCableTitle),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _connectorOrientation(context),
                    const SizedBox(height: 16),
                    _pinoutCard('T568B', 'Padrão mais usado no Brasil', _t568b),
                    const SizedBox(height: 12),
                    _pinoutCard('T568A', 'Par verde e laranja invertidos vs. B', _t568a),
                    const SizedBox(height: 16),
                    _straightVsCrossover(context),
                    const SizedBox(height: 16),
                    _categoriesCard(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Orientação do pino 1 no conector
  Widget _connectorOrientation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.netCablePinout,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 90,
              child: CustomPaint(
                size: const Size(150, 90),
                painter: _ConnectorPainter(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.netCableHold,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinoutCard(String title, String subtitle, List<_PinColor> pins) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          ...List.generate(pins.length, (i) => _pinRow(i + 1, pins[i])),
        ],
      ),
    );
  }

  Widget _pinRow(int pin, _PinColor p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$pin',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
          // amostra de cor (listrada para pares branco/cor)
          Container(
            width: 40,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              gradient: p.striped
                  ? LinearGradient(
                      colors: [Colors.white, p.color, Colors.white, p.color],
                      stops: const [0.0, 0.33, 0.5, 1.0],
                    )
                  : null,
              color: p.striped ? null : p.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(p.name,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _straightVsCrossover(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lan_outlined, color: AppColors.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.netCableStraight,
              style: TextStyle(
                color: AppColors.blue.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.netCableCats,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 12),
          _catHeader(context),
          const Divider(color: AppColors.cardBorder, height: 16),
          ..._categories.map(_catRow),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.netCableLength,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _catHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.netCableCat, style: _hStyle)),
        Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.netCableBand, style: _hStyle)),
        Expanded(flex: 3, child: Text(AppLocalizations.of(context)!.netCableSpeed, style: _hStyle)),
        Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.netCableMax, style: _hStyle)),
      ],
    );
  }

  Widget _catRow(_CableCat c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(c.cat,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))),
          Expanded(
              flex: 2,
              child: Text(c.band, style: _cStyle)),
          Expanded(
              flex: 3,
              child: Text(c.speed, style: _cStyle)),
          Expanded(
              flex: 2,
              child: Text(c.length, style: _cStyle)),
        ],
      ),
    );
  }

  static const _hStyle = TextStyle(
      color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800);
  static const _cStyle = TextStyle(color: AppColors.textSecondary, fontSize: 12);
}

// Desenho simples de um conector RJ-45 com o pino 1 destacado.
class _ConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // corpo do conector
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 10, size.width - 20, size.height - 30),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, body);
    canvas.drawRRect(rect, border);

    // trava (clip) embaixo
    final clip = Path()
      ..moveTo(size.width / 2 - 12, size.height - 20)
      ..lineTo(size.width / 2 - 16, size.height - 6)
      ..lineTo(size.width / 2 + 16, size.height - 6)
      ..lineTo(size.width / 2 + 12, size.height - 20)
      ..close();
    canvas.drawPath(clip, body);
    canvas.drawPath(clip, border);

    // 8 contatos no topo
    const n = 8;
    final usable = size.width - 28;
    final step = usable / n;
    for (var i = 0; i < n; i++) {
      final x = 14 + step * i + step / 2;
      final isPin1 = i == 0;
      final p = Paint()
        ..color = isPin1 ? AppColors.gold : AppColors.textMuted
        ..strokeWidth = isPin1 ? 4 : 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, 14), Offset(x, 30), p);
    }

    // rótulo "1"
    final tp = TextPainter(
      text: const TextSpan(
        text: '1',
        style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(14 + step / 2 - tp.width / 2, 34));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
