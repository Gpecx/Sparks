import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/spda_calc.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class SpdaCalcScreen extends StatefulWidget {
  const SpdaCalcScreen({super.key});

  @override
  State<SpdaCalcScreen> createState() => _SpdaCalcScreenState();
}

class _SpdaCalcScreenState extends State<SpdaCalcScreen> {
  String _level = 'II';

  // Gerais
  final _perimeter = TextEditingController(text: '80');
  final _height = TextEditingController(text: '12');

  // Distância de segurança
  final _kc = TextEditingController(text: '0.5');
  final _km = TextEditingController(text: '1.0');
  final _length = TextEditingController(text: '10');

  SpdaGeneralResult? _general;
  double? _safety;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_perimeter, _height, _kc, _km, _length]) {
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
    final per = _p(_perimeter);
    final h = _p(_height);
    if (per == null || h == null || per <= 0 || h <= 0) {
      setState(() {
        _warning = 'Preencha perímetro e altura (> 0).';
        _general = null;
      });
      return;
    }
    final g = spdaGeneral(level: _level, perimeter: per, height: h);

    double? s;
    final kc = _p(_kc);
    final km = _p(_km);
    final len = _p(_length);
    if (kc != null && km != null && len != null && km > 0) {
      s = safetyDistance(level: _level, kc: kc, km: km, length: len);
    }

    setState(() {
      _warning = null;
      _general = g;
      _safety = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'SPDA — Cálculos (5419-3)',
      children: [
        _infoBox(),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Nível de proteção',
          children: [
            ToolSegmented(
              labels: const ['I', 'II', 'III', 'IV'],
              selected: ['I', 'II', 'III', 'IV'].indexOf(_level),
              onSelect: (i) =>
                  setState(() => _level = ['I', 'II', 'III', 'IV'][i]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Estrutura',
          subtitle: 'Perímetro (para nº de descidas) e altura (ângulo).',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _perimeter, label: 'Perímetro (m)'),
              ToolField(controller: _height, label: 'Altura (m)'),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Distância de segurança (opcional)',
          subtitle: 's = ki·(kc/km)·L  ·  km: ar=1, sólido=0,5',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _kc, label: 'kc (divisão)'),
              ToolField(controller: _km, label: 'km (isolamento)'),
              ToolField(controller: _length, label: 'L (m)'),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: const [], warning: _warning),
        ],
        if (_general != null) ...[
          const SizedBox(height: 24),
          _resultsPanel(_general!),
        ],
      ],
    );
  }

  Widget _resultsPanel(SpdaGeneralResult g) {
    final results = <ToolResult>[
      ToolResult('Raio da esfera rolante', '${fmtNumber(g.rollingSphereRadius, decimals: 0)} m'),
      ToolResult('Nº de condutores de descida', '${g.downConductorCount}'),
      ToolResult('Ângulo de proteção α', '${fmtNumber(g.protectionAngle, decimals: 1)}°'),
      ToolResult('Raio de proteção no solo', '${fmtNumber(g.protectionRadius, decimals: 2)} m'),
      ToolResult('Corrente de impulso (nível $_level)', '${fmtNumber(g.impulseCurrentKa, decimals: 0)} kA'),
      ToolResult('Seção mín. captação (Cu)', '${fmtNumber(conductorSectionCopper.airTerminationCopper, decimals: 0)} mm²'),
      ToolResult('Seção mín. descida (Cu)', '${fmtNumber(conductorSectionCopper.downConductorCopper, decimals: 0)} mm²'),
      ToolResult('Seção mín. aterramento (Cu)', '${fmtNumber(conductorSectionCopper.earthCopper, decimals: 0)} mm²'),
    ];
    if (_safety != null && !_safety!.isNaN) {
      results.add(ToolResult('Distância de segurança s',
          '${fmtNumber(_safety!, decimals: 3)} m'));
    }
    return ToolResultsPanel(
      results: results,
      title: 'Resultados (nível $_level)',
      note: 'Valores tabelados da NBR 5419-3. O ângulo de proteção é aproximado '
          'das curvas da norma — confirme no gráfico do Anexo A para o projeto.',
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cálculos gerais de SPDA (NBR 5419-3): esfera rolante, nº de '
              'descidas, ângulo de proteção, corrente de impulso, seções e '
              'distância de segurança. Triagem — confirme no projeto.',
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
