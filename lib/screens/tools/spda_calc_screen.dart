import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
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
      title: AppLocalizations.of(context)!.tlSpdaCalc,
      children: [
        _infoBox(),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.spdaCalcLevel,
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
          title: AppLocalizations.of(context)!.spdaCalcStruct,
          subtitle: AppLocalizations.of(context)!.spdaCalcPerimDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _perimeter, label: AppLocalizations.of(context)!.spdaCalcPerim),
              ToolField(controller: _height, label: AppLocalizations.of(context)!.spdaCalcH),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.spdaCalcDist,
          subtitle: AppLocalizations.of(context)!.spdaCalcSDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _kc, label: AppLocalizations.of(context)!.spdaCalcKc),
              ToolField(controller: _km, label: AppLocalizations.of(context)!.spdaCalcKm),
              ToolField(controller: _length, label: AppLocalizations.of(context)!.spdaCalcL),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: AppLocalizations.of(context)!.tlBtnCalculate, onPressed: _calculate),
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
      ToolResult(AppLocalizations.of(context)!.spdaCalcSphere, '${fmtNumber(g.rollingSphereRadius, decimals: 0)} m'),
      ToolResult(AppLocalizations.of(context)!.spdaCalcDownNum, '${g.downConductorCount}'),
      ToolResult(AppLocalizations.of(context)!.spdaCalcAngle, '${fmtNumber(g.protectionAngle, decimals: 1)}°'),
      ToolResult(AppLocalizations.of(context)!.spdaCalcRadius, '${fmtNumber(g.protectionRadius, decimals: 2)} m'),
      ToolResult('Corrente de impulso (nível $_level)', '${fmtNumber(g.impulseCurrentKa, decimals: 0)} kA'),
      ToolResult(AppLocalizations.of(context)!.spdaCalcCaptSec, '${fmtNumber(conductorSectionCopper.airTerminationCopper, decimals: 0)} mm²'),
      ToolResult(AppLocalizations.of(context)!.spdaCalcDownSec, '${fmtNumber(conductorSectionCopper.downConductorCopper, decimals: 0)} mm²'),
      ToolResult(AppLocalizations.of(context)!.spdaCalcGndSec, '${fmtNumber(conductorSectionCopper.earthCopper, decimals: 0)} mm²'),
    ];
    if (_safety != null && !_safety!.isNaN) {
      results.add(ToolResult(AppLocalizations.of(context)!.spdaCalcSafeDist,
          '${fmtNumber(_safety!, decimals: 3)} m'));
    }
    return ToolResultsPanel(
      results: results,
      title: AppLocalizations.of(context)!.tlResultsLevel(_level.toString()),
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
              AppLocalizations.of(context)!.spdaCalcDesc,
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
