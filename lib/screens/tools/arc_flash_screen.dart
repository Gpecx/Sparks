import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/arc_flash.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class ArcFlashScreen extends StatefulWidget {
  const ArcFlashScreen({super.key});

  @override
  State<ArcFlashScreen> createState() => _ArcFlashScreenState();
}

class _ArcFlashScreenState extends State<ArcFlashScreen> {
  EnclosureFactor _preset = enclosurePresets.first;
  ArcEnclosure _enclosure = ArcEnclosure.box;

  final _iBf = TextEditingController(text: '25');
  final _voltage = TextEditingController(text: '0.48');
  final _time = TextEditingController(text: '0.1');
  final _distance = TextEditingController(text: '455');
  final _gap = TextEditingController(text: '25');

  ArcFlashResult? _result;
  double? _safeDist;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_iBf, _voltage, _time, _distance, _gap]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _applyPreset(EnclosureFactor f) {
    setState(() {
      _preset = f;
      _gap.text = f.gapMm.toStringAsFixed(0);
      _enclosure =
          f.name.contains('open') ? ArcEnclosure.open : ArcEnclosure.box;
    });
  }

  void _calculate() {
    final ibf = _p(_iBf);
    final v = _p(_voltage);
    final t = _p(_time);
    final d = _p(_distance);
    final g = _p(_gap);
    if (ibf == null || v == null || t == null || d == null || g == null ||
        ibf <= 0 || v <= 0 || t <= 0 || d <= 0 || g <= 0) {
      setState(() {
        _warning = 'Preencha corrente, tensão, tempo, distância e gap (> 0).';
        _result = null;
      });
      return;
    }

    final r = arcFlashIeee1584(
      iBfKa: ibf,
      voltageKv: v,
      clearingTimeS: t,
      workingDistanceMm: d,
      gapMm: g,
      distanceExponent: _preset.distanceExponent,
      enclosure: _enclosure,
    );
    final safe = safeApproachDistanceMm(
        iBfKa: ibf, voltageKv: v, clearingTimeS: t);

    setState(() {
      _warning = null;
      _result = r;
      _safeDist = safe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Arc Flash (energia incidente)',
      children: [
        _disclaimerBox(),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.arcFlashEquipClass,
          subtitle: AppLocalizations.of(context)!.arcFlashDefineGap,
          children: [
            DropdownButtonFormField<EnclosureFactor>(
              initialValue: _preset,
              isExpanded: true,
              dropdownColor: AppColors.card,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              items: [
                for (final f in enclosurePresets)
                  DropdownMenuItem(
                    value: f,
                    child: Text('${f.name}  ·  gap ${f.gapMm.toStringAsFixed(0)} mm'),
                  ),
              ],
              onChanged: (f) {
                if (f != null) _applyPreset(f);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.arcFlashParams,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _iBf, label: AppLocalizations.of(context)!.arcFlashIbf),
              ToolField(controller: _voltage, label: AppLocalizations.of(context)!.arcFlashVolt),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(controller: _time, label: AppLocalizations.of(context)!.arcFlashTime),
              ToolField(controller: _gap, label: AppLocalizations.of(context)!.arcFlashGap),
            ]),
            const SizedBox(height: 12),
            ToolField(
                controller: _distance, label: AppLocalizations.of(context)!.arcFlashWorkDist),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: const [], warning: _warning),
        ],
        if (_result != null) ...[
          const SizedBox(height: 24),
          _resultCard(_result!),
        ],
      ],
    );
  }

  Widget _resultCard(ArcFlashResult r) {
    final cat = r.ppeCategory;
    final color = _catColor(cat);
    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.arcFlashEnergy,
          '${fmtNumber(r.incidentEnergy, decimals: 2)} cal/cm²'),
      if (!r.arcingCurrentKa.isNaN)
        ToolResult(AppLocalizations.of(context)!.arcFlashIa,
            '${fmtNumber(r.arcingCurrentKa, decimals: 2)} kA'),
      if (_safeDist != null && !_safeDist!.isNaN)
        ToolResult(AppLocalizations.of(context)!.arcFlashSafeDist,
            '${fmtNumber(_safeDist!, decimals: 0)} mm'),
      ToolResult(AppLocalizations.of(context)!.arcFlashModel, r.model),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(cat == -1 ? Icons.dangerous : Icons.shield_outlined,
                      color: color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ppeLabel(cat),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${fmtNumber(r.incidentEnergy, decimals: 2)} cal/cm² '
                'a ${_distance.text} mm',
                style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ToolResultsPanel(
          results: results,
          title: AppLocalizations.of(context)!.arcFlashResult,
          note: r.outOfRange
              ? 'Fora da faixa de validade do IEEE 1584-2002 (208 V–15 kV, '
                  '0,7–106 kA, gap 13–152 mm) — usado o modelo de Lee, mais '
                  'conservador. Confirme com estudo formal.'
              : 'Estimativa de triagem. Não substitui o estudo de arc flash '
                  'formal com dados reais de curto e tempos dos relés.',
        ),
      ],
    );
  }

  Color _catColor(int cat) {
    switch (cat) {
      case -1:
        return const Color(0xFFDC2626);
      case 4:
        return const Color(0xFFEA580C);
      case 3:
        return const Color(0xFFF97316);
      case 2:
        return const Color(0xFFEAB308);
      case 1:
        return const Color(0xFF84CC16);
      default:
        return AppColors.primary;
    }
  }

  Widget _disclaimerBox() {
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
              AppLocalizations.of(context)!.arcFlashDesc
              'NÃO substitui o estudo formal de arc flash — use a corrente de '
              'curto real e os tempos de eliminação dos relés do barramento.',
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
