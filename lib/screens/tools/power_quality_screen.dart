import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/power_quality.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class PowerQualityScreen extends StatefulWidget {
  const PowerQualityScreen({super.key});

  @override
  State<PowerQualityScreen> createState() => _PowerQualityScreenState();
}

class _PowerQualityScreenState extends State<PowerQualityScreen> {
  int _tab = 0; // 0 = carregamento, 1 = desequilíbrio

  // Carregamento
  final _vLL = TextEditingController(text: '13.8');
  final _current = TextEditingController(text: '400');
  final _ratedKva = TextEditingController(text: '10000');

  // Desequilíbrio
  int _unbMode = 0; // 0 = PRODIST (mód+âng), 1 = aproximada (só módulos)
  final _va = TextEditingController(text: '220');
  final _vaAng = TextEditingController(text: '0');
  final _vb = TextEditingController(text: '215');
  final _vbAng = TextEditingController(text: '-120');
  final _vc = TextEditingController(text: '222');
  final _vcAng = TextEditingController(text: '120');

  List<ToolResult>? _results;
  String? _warning;
  String? _note;
  Color _verdictColor = AppColors.primary;
  String? _verdict;

  @override
  void dispose() {
    for (final c in [
      _vLL, _current, _ratedKva,
      _va, _vaAng, _vb, _vbAng, _vc, _vcAng,
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

  void _calcLoading() {
    final v = _p(_vLL);
    final i = _p(_current);
    final s = _p(_ratedKva);
    if (v == null || i == null || s == null || v <= 0 || s <= 0) {
      setState(() {
        _warning = 'Preencha tensão, corrente e potência nominal (> 0).';
        _results = null;
        _verdict = null;
      });
      return;
    }
    final r = transformerLoading(vLLkv: v, currentA: i, ratedKva: s);
    String classify;
    Color color;
    if (r.loadingPercent <= 80) {
      classify = 'Normal (≤ 80%)';
      color = AppColors.primary;
    } else if (r.loadingPercent <= 100) {
      classify = 'Atenção (80–100%)';
      color = AppColors.warning;
    } else {
      classify = 'Sobrecarga (> 100%)';
      color = AppColors.error;
    }
    setState(() {
      _warning = null;
      _verdict = classify;
      _verdictColor = color;
      _note = 'S = √3 · V_LL · I. Limites de referência operacional (ajuste conforme a norma/projeto).';
      _results = [
        ToolResult(AppLocalizations.of(context)!.powerQualityMeasPower, '${fmtNumber(r.apparentKva, decimals: 1)} kVA'),
        ToolResult(AppLocalizations.of(context)!.powerQualityNomPowerShort, '${fmtNumber(s, decimals: 0)} kVA'),
        ToolResult(AppLocalizations.of(context)!.powerQualityLoadPct, '${fmtNumber(r.loadingPercent, decimals: 1)} %'),
      ];
    });
  }

  void _calcUnbalance() {
    final va = _p(_va), vb = _p(_vb), vc = _p(_vc);
    if (va == null || vb == null || vc == null || va <= 0 || vb <= 0 || vc <= 0) {
      setState(() {
        _warning = 'Preencha as três tensões (> 0).';
        _results = null;
        _verdict = null;
      });
      return;
    }

    final results = <ToolResult>[];
    double fd;
    if (_unbMode == 0) {
      final aA = _p(_vaAng) ?? 0, aB = _p(_vbAng) ?? -120, aC = _p(_vcAng) ?? 120;
      fd = voltageUnbalanceProdist(
        va: va, angA: aA, vb: vb, angB: aB, vc: vc, angC: aC,
      );
      results.add(ToolResult(AppLocalizations.of(context)!.powerQualityFdProdist, '${fmtNumber(fd, decimals: 3)} %'));
    } else {
      fd = voltageUnbalanceApprox(v1: va, v2: vb, v3: vc);
      final nema = maxDeviationUnbalance(v1: va, v2: vb, v3: vc);
      results.add(ToolResult(AppLocalizations.of(context)!.powerQualityFdCigre, '${fmtNumber(fd, decimals: 3)} %'));
      results.add(ToolResult(AppLocalizations.of(context)!.powerQualityDevNema, '${fmtNumber(nema, decimals: 3)} %'));
    }

    // Limite PRODIST Módulo 8 (referência): 3% (Vn ≤ 1 kV) / 2% (1 kV < Vn ≤ 230 kV)
    String classify;
    Color color;
    if (fd <= 2.0) {
      classify = 'Dentro do limite (≤ 2%)';
      color = AppColors.primary;
    } else if (fd <= 3.0) {
      classify = 'Limite conforme nível de tensão (2–3%)';
      color = AppColors.warning;
    } else {
      classify = 'Acima do limite (> 3%)';
      color = AppColors.error;
    }

    setState(() {
      _warning = null;
      _verdict = classify;
      _verdictColor = color;
      _note =
          'Limites de referência PRODIST Módulo 8: 3% para Vn ≤ 1 kV e 2% para 1 kV < Vn ≤ 230 kV. '
          'Confirme o limite aplicável ao seu nível de tensão.';
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: AppLocalizations.of(context)!.tlPowerQuality,
      children: [
        ToolSegmented(
          labels: [AppLocalizations.of(context)!.powerQualityLoadPct, AppLocalizations.of(context)!.powerQualityImbalance],
          selected: _tab,
          onSelect: (i) => setState(() {
            _tab = i;
            _results = null;
            _warning = null;
            _verdict = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_tab == 0) ..._loadingInputs() else ..._unbalanceInputs(),
        const SizedBox(height: 20),
        ToolButton(
          label: AppLocalizations.of(context)!.tlBtnCalculate,
          onPressed: _tab == 0 ? _calcLoading : _calcUnbalance,
        ),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          if (_verdict != null) _verdictBox(),
          if (_verdict != null) const SizedBox(height: 12),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
            note: _results != null ? _note : null,
          ),
        ],
      ],
    );
  }

  List<Widget> _loadingInputs() => [
        ToolCard(
          title: AppLocalizations.of(context)!.powerQualityTransfLoad,
          subtitle: AppLocalizations.of(context)!.powerQualityLoadDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _vLL, label: AppLocalizations.of(context)!.powerQualityVLL),
              ToolField(controller: _current, label: AppLocalizations.of(context)!.powerQualityCur),
            ]),
            const SizedBox(height: 12),
            ToolField(controller: _ratedKva, label: AppLocalizations.of(context)!.powerQualityNomPower),
          ],
        ),
      ];

  List<Widget> _unbalanceInputs() => [
        ToolSegmented(
          labels: ['PRODIST (mód+âng)', 'Aproximada (só mód.)'],
          selected: _unbMode,
          onSelect: (i) => setState(() {
            _unbMode = i;
            _results = null;
          }),
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.powerQualityPhaseV,
          subtitle: _unbMode == 0
              ? 'FD% = V₂/V₁ (componentes simétricas) — método oficial PRODIST'
              : 'FD% aproximado a partir dos módulos das três tensões',
          children: [
            _phaseRow('Va', _va, _vaAng),
            const SizedBox(height: 10),
            _phaseRow('Vb', _vb, _vbAng),
            const SizedBox(height: 10),
            _phaseRow('Vc', _vc, _vcAng),
          ],
        ),
      ];

  Widget _phaseRow(String label, TextEditingController mag, TextEditingController ang) {
    if (_unbMode == 1) {
      return ToolField(controller: mag, label: '$label (V)');
    }
    return ToolFieldRow(children: [
      ToolField(controller: mag, label: '$label (V)'),
      ToolField(controller: ang, label: AppLocalizations.of(context)!.powerQualityPhaseAng, signed: true),
    ]);
  }

  Widget _verdictBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _verdictColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _verdictColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            _verdictColor == AppColors.primary
                ? Icons.check_circle
                : Icons.warning_amber_rounded,
            color: _verdictColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _verdict!,
              style: TextStyle(
                  color: _verdictColor, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
