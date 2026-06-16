import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/spda_risk.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class SpdaRiskScreen extends StatefulWidget {
  const SpdaRiskScreen({super.key});

  @override
  State<SpdaRiskScreen> createState() => _SpdaRiskScreenState();
}

class _SpdaRiskScreenState extends State<SpdaRiskScreen> {
  final _length = TextEditingController(text: '30');
  final _width = TextEditingController(text: '20');
  final _height = TextEditingController(text: '12');
  final _ng = TextEditingController(text: '6');
  StructureLocation _location = StructureLocation.isolated;

  SpdaRiskResult? _result;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_length, _width, _height, _ng]) {
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
    final l = _p(_length);
    final w = _p(_width);
    final h = _p(_height);
    final ng = _p(_ng);
    if (l == null || w == null || h == null || ng == null ||
        l <= 0 || w <= 0 || h <= 0 || ng < 0) {
      setState(() {
        _warning = 'Preencha dimensões (> 0) e a densidade Ng (≥ 0).';
        _result = null;
      });
      return;
    }
    final r = spdaRiskScreening(
      length: l, width: w, height: h, ngDensity: ng, location: _location,
    );
    setState(() {
      _warning = null;
      _result = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'SPDA — Análise de Risco',
      children: [
        _infoBox(),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.spdaRiskStruct,
          subtitle: AppLocalizations.of(context)!.spdaRiskAdDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _length, label: AppLocalizations.of(context)!.spdaRiskL),
              ToolField(controller: _width, label: AppLocalizations.of(context)!.spdaRiskW),
            ]),
            const SizedBox(height: 12),
            ToolField(controller: _height, label: AppLocalizations.of(context)!.spdaRiskH),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.spdaRiskExp,
          subtitle: AppLocalizations.of(context)!.spdaRiskNgDesc,
          children: [
            ToolField(controller: _ng, label: AppLocalizations.of(context)!.spdaRiskNg),
            const SizedBox(height: 12),
            DropdownButtonFormField<StructureLocation>(
              initialValue: _location,
              isExpanded: true,
              dropdownColor: AppColors.card,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              items: const [
                DropdownMenuItem(
                    value: StructureLocation.surrounded,
                    child: Text(AppLocalizations.of(context)!.spdaRiskSurrounded)),
                DropdownMenuItem(
                    value: StructureLocation.near,
                    child: Text(AppLocalizations.of(context)!.spdaRiskSameH)),
                DropdownMenuItem(
                    value: StructureLocation.isolated,
                    child: Text(AppLocalizations.of(context)!.spdaRiskIso)),
                DropdownMenuItem(
                    value: StructureLocation.isolatedHill,
                    child: Text(AppLocalizations.of(context)!.spdaRiskIsoHill)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _location = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'AVALIAR', onPressed: _calculate),
        if (_warning != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: const [], warning: _warning),
        ],
        if (_result != null) ...[
          const SizedBox(height: 24),
          _verdictBox(_result!),
          const SizedBox(height: 12),
          _resultsPanel(_result!),
        ],
      ],
    );
  }

  Widget _verdictBox(SpdaRiskResult r) {
    final needed = r.spdaLikelyNeeded;
    final color = needed ? AppColors.warning : AppColors.primary;
    final text = needed
        ? 'SPDA indicado — nível provável ${r.suggestedLevel}'
        : 'SPDA tende a ser dispensável (Nd abaixo da frequência admissível)';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(needed ? Icons.flash_on : Icons.verified_outlined,
              color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsPanel(SpdaRiskResult r) {
    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.spdaRiskAd, '${fmtNumber(r.collectionAreaAd, decimals: 0)} m²'),
      ToolResult(AppLocalizations.of(context)!.spdaRiskNd, '${r.dangerousEvents.toStringAsExponential(2)} /ano'),
      ToolResult(AppLocalizations.of(context)!.spdaRiskNc, '${r.admissibleFrequency.toStringAsExponential(0)} /ano'),
      if (r.spdaLikelyNeeded)
        ToolResult(AppLocalizations.of(context)!.spdaRiskEff, '${fmtNumber(r.requiredEfficiency * 100, decimals: 1)} %'),
      if (r.suggestedLevel != null)
        ToolResult(AppLocalizations.of(context)!.spdaRiskLevel, r.suggestedLevel!),
    ];
    return ToolResultsPanel(
      results: results,
      title: AppLocalizations.of(context)!.spdaRiskEval,
      note: 'Triagem simplificada (Nd vs frequência admissível Nc). A NBR 5419-2 exige a '
          'soma das componentes de risco (RA…RZ) com coeficientes P/L — faça o '
          'estudo formal e a ART para o projeto definitivo.',
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.spdaRiskDesc
              'perigosos e indica o nível provável. NÃO substitui a análise de '
              'risco completa nem a ART do projeto.',
              style: TextStyle(
                color: AppColors.warning.withValues(alpha: 0.95),
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
