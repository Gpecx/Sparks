import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/thermal_severity.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class ThermalSeverityScreen extends StatefulWidget {
  const ThermalSeverityScreen({super.key});

  @override
  State<ThermalSeverityScreen> createState() => _ThermalSeverityScreenState();
}

class _ThermalSeverityScreenState extends State<ThermalSeverityScreen> {
  final _deltaT = TextEditingController(text: '8');
  final _iMed = TextEditingController(text: '');
  final _iNom = TextEditingController(text: '');

  List<ToolResult>? _results;
  String? _warning;
  ThermalClass? _verdict;

  @override
  void dispose() {
    _deltaT.dispose();
    _iMed.dispose();
    _iNom.dispose();
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _calculate() {
    final dt = _p(_deltaT);
    if (dt == null) {
      setState(() {
        _warning = 'Informe o ΔT medido (°C).';
        _results = null;
        _verdict = null;
      });
      return;
    }

    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.thermalMeasDt, '${fmtNumber(dt, decimals: 1)} °C'),
    ];

    var classifyValue = dt;
    final im = _p(_iMed);
    final inom = _p(_iNom);
    if (im != null && inom != null && im > 0) {
      final corr = correctDeltaTForLoad(
          deltaTMeasured: dt, currentMeasured: im, currentNominal: inom);
      results.add(ToolResult(AppLocalizations.of(context)!.thermalCorDt, '${fmtNumber(corr, decimals: 1)} °C'));
      classifyValue = corr;
    }

    final cls = classifySimilarComponent(classifyValue);
    results.add(ToolResult(AppLocalizations.of(context)!.thermalClass, cls.label));

    setState(() {
      _warning = null;
      _verdict = cls;
      _results = results;
    });
  }

  Color _color(int level) {
    switch (level) {
      case 0:
        return AppColors.primary;
      case 1:
        return AppColors.blue;
      case 2:
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Severidade Térmica',
      children: [
        ToolCard(
          title: AppLocalizations.of(context)!.thermalAnomaly,
          subtitle:
              AppLocalizations.of(context)!.thermalDesc,
          children: [
            ToolField(controller: _deltaT, label: AppLocalizations.of(context)!.thermalDeltaT),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.thermalCorrection,
          subtitle: AppLocalizations.of(context)!.thermalCorDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _iMed, label: AppLocalizations.of(context)!.thermalMeasI),
              ToolField(controller: _iNom, label: AppLocalizations.of(context)!.thermalNomI),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          if (_verdict != null) _verdictBox(_verdict!),
          if (_verdict != null) const SizedBox(height: 12),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
            title: AppLocalizations.of(context)!.thermalDiag,
          ),
        ],
      ],
    );
  }

  Widget _verdictBox(ThermalClass cls) {
    final color = _color(cls.level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.thermostat, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  cls.action,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
