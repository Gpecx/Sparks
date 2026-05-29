import 'package:flutter/material.dart';
import 'package:spark_app/utils/distance_protection.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class DistanceProtectionScreen extends StatefulWidget {
  const DistanceProtectionScreen({super.key});

  @override
  State<DistanceProtectionScreen> createState() =>
      _DistanceProtectionScreenState();
}

class _DistanceProtectionScreenState extends State<DistanceProtectionScreen> {
  final _zLine = TextEditingController(text: '10');
  final _zAdjacent = TextEditingController(text: '8');
  final _z1Pct = TextEditingController(text: '85');
  final _z2Factor = TextEditingController(text: '0.5');
  final _z3Factor = TextEditingController(text: '1.0');
  final _rtc = TextEditingController(text: '');
  final _rtp = TextEditingController(text: '');

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    for (final c in [
      _zLine, _zAdjacent, _z1Pct, _z2Factor, _z3Factor, _rtc, _rtp,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _calculate() {
    final zl = _p(_zLine);
    final za = _p(_zAdjacent) ?? 0;
    final z1p = _p(_z1Pct) ?? 85;
    final z2f = _p(_z2Factor) ?? 0.5;
    final z3f = _p(_z3Factor) ?? 1.0;
    if (zl == null || zl <= 0) {
      setState(() {
        _warning = 'Informe a impedância da linha (Ω) maior que zero.';
        _results = null;
      });
      return;
    }

    final r = distanceZones(
      lineImpedance: zl,
      adjacentImpedance: za,
      zone1Percent: z1p,
      zone2AdjacentFactor: z2f,
      zone3AdjacentFactor: z3f,
      rtc: _p(_rtc),
      rtp: _p(_rtp),
    );

    final results = <ToolResult>[
      ToolResult('Zona 1 (~instantâneo)', '${fmtNumber(r.z1, decimals: 3)} Ω prim'),
      ToolResult('Zona 2 (~0,3–0,4 s)', '${fmtNumber(r.z2, decimals: 3)} Ω prim'),
      ToolResult('Zona 3 (~0,8–1,0 s)', '${fmtNumber(r.z3, decimals: 3)} Ω prim'),
    ];
    if (r.z1Secondary != null) {
      results.addAll([
        ToolResult('Zona 1 secundária', '${fmtNumber(r.z1Secondary!, decimals: 3)} Ω sec'),
        ToolResult('Zona 2 secundária', '${fmtNumber(r.z2Secondary!, decimals: 3)} Ω sec'),
        ToolResult('Zona 3 secundária', '${fmtNumber(r.z3Secondary!, decimals: 3)} Ω sec'),
      ]);
    }

    setState(() {
      _warning = null;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Proteção de Distância (21)',
      children: [
        ToolCard(
          title: 'Impedâncias',
          subtitle:
              'Z1 = z1%·Z_linha · Z2 = Z_linha + f2·Z_adj · Z3 = Z_linha + f3·Z_adj',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _zLine, label: 'Z linha (Ω)'),
              ToolField(controller: _zAdjacent, label: 'Z linha adjacente (Ω)'),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Ajustes das zonas',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _z1Pct, label: 'Zona 1 (%)'),
              ToolField(controller: _z2Factor, label: 'Fator Z2 adj.'),
              ToolField(controller: _z3Factor, label: 'Fator Z3 adj.'),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Conversão para secundário (opcional)',
          subtitle: 'Z_sec = Z_prim · (RTC / RTP)',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _rtc, label: 'RTC'),
              ToolField(controller: _rtp, label: 'RTP'),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
            title: 'Alcance das zonas',
            note:
                'Tempos típicos de referência. Ajuste Z1 a 80–85% e garanta Z2 ≥ 120% da linha.',
          ),
        ],
      ],
    );
  }
}
