import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/ons_voltage_base.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class OnsVoltageScreen extends StatefulWidget {
  const OnsVoltageScreen({super.key});

  @override
  State<OnsVoltageScreen> createState() => _OnsVoltageScreenState();
}

class _OnsVoltageScreenState extends State<OnsVoltageScreen> {
  int _mode = 0; // 0 = pu(ONS) -> V sec, 1 = V sec -> pu(ONS)

  final _vBaseOns = TextEditingController(text: '230');
  final _vTpPrim = TextEditingController(text: '245');
  final _vTpSec = TextEditingController(text: '115');
  final _puOns = TextEditingController(text: '1.05');
  final _vSec = TextEditingController(text: '115');

  List<ToolResult>? _results;
  String? _warning;
  String? _note;

  @override
  void dispose() {
    for (final c in [_vBaseOns, _vTpPrim, _vTpSec, _puOns, _vSec]) {
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
    final vBase = _p(_vBaseOns);
    final vPrim = _p(_vTpPrim);
    final vSecNom = _p(_vTpSec);
    if (vBase == null || vPrim == null || vSecNom == null ||
        vBase <= 0 || vPrim <= 0 || vSecNom <= 0) {
      setState(() {
        _warning = 'Preencha a base do ONS e as tensões nominais do TP (> 0).';
        _results = null;
      });
      return;
    }

    final mismatch = baseMismatchErrorPercent(
        vBaseOnsKv: vBase, vNominalTpPrimaryKv: vPrim);

    OnsVoltageResult r;
    if (_mode == 0) {
      final pu = _p(_puOns);
      if (pu == null) {
        setState(() {
          _warning = 'Informe o valor em pu (base ONS).';
          _results = null;
        });
        return;
      }
      r = onsPuToSecondary(
        puOns: pu,
        vBaseOnsKv: vBase,
        vNominalTpPrimaryKv: vPrim,
        vTpSecondaryV: vSecNom,
      );
    } else {
      final vs = _p(_vSec);
      if (vs == null) {
        setState(() {
          _warning = 'Informe a tensão secundária medida (V).';
          _results = null;
        });
        return;
      }
      r = secondaryToOnsPu(
        secondaryV: vs,
        vBaseOnsKv: vBase,
        vNominalTpPrimaryKv: vPrim,
        vTpSecondaryV: vSecNom,
      );
    }

    // valor "ingênuo": aplicar o pu do ONS direto sobre o secundário nominal
    final naive = _mode == 0 ? (r.puOnsBase * vSecNom) : null;

    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.onsVoltagePrimResult, '${fmtNumber(r.primaryKv, decimals: 3)} kV'),
      ToolResult('pu na base do TP', fmtNumber(r.puTpBase, decimals: 4)),
      ToolResult('pu na base do ONS', fmtNumber(r.puOnsBase, decimals: 4)),
      ToolResult('Tensão secundária (correta)', '${fmtNumber(r.secondaryVolts, decimals: 2)} V'),
    ];
    if (naive != null) {
      results.add(ToolResult('Secundária (erro: pu×Vsec direto)',
          '${fmtNumber(naive, decimals: 2)} V'));
    }

    setState(() {
      _warning = null;
      _note =
          'Diferença entre a base do ONS (${fmtNumber(vBase, decimals: 0)} kV) e o nominal do TP '
          '(${fmtNumber(vPrim, decimals: 0)} kV): ${fmtNumber(mismatch, decimals: 2)}%. '
          'Ignorar essa diferença causa erro de mesma ordem nos ajustes de 25, 59, 27 e religamento.';
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: AppLocalizations.of(context)!.tlOnsVoltage,
      children: [
        ToolSegmented(
          labels: const ['pu(ONS) → V sec', 'V sec → pu(ONS)'],
          selected: _mode,
          onSelect: (i) => setState(() {
            _mode = i;
            _results = null;
            _warning = null;
          }),
        ),
        const SizedBox(height: 16),
        ToolCard(
          title: AppLocalizations.of(context)!.tlVoltageBases,
          subtitle:
              'A base do estudo do ONS (ex.: 230/500 kV) costuma diferir do nominal real do TP.',
          children: [
            ToolField(
              controller: _vBaseOns,
              label: AppLocalizations.of(context)!.tlOnsBaseV,
              semantic: 'Tensão de base do ONS em kV',
            ),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(
                controller: _vTpPrim,
                label: AppLocalizations.of(context)!.tlVtPrimary,
                semantic: 'Tensão nominal do primário do TP',
              ),
              ToolField(
                controller: _vTpSec,
                label: AppLocalizations.of(context)!.tlVtSecondary,
                semantic: 'Tensão nominal do secundário do TP',
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: _mode == 0 ? 'Valor do estudo' : 'Valor medido',
          children: [
            if (_mode == 0)
              ToolField(
                controller: _puOns,
                label: AppLocalizations.of(context)!.tlVoltagePuOns,
                semantic: 'Valor em pu na base do ONS',
              )
            else
              ToolField(
                controller: _vSec,
                label: AppLocalizations.of(context)!.tlSecondaryMeasured,
                semantic: 'Tensão secundária medida em volts',
              ),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: AppLocalizations.of(context)!.tlBtnCalculate, onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
            title: AppLocalizations.of(context)!.tlVoltageConversion,
            note: _results != null ? _note : null,
          ),
        ],
        const SizedBox(height: 16),
        _infoBox(),
      ],
    );
  }

  Widget _infoBox() {
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
          const Icon(Icons.info_outline, color: AppColors.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'O estudo do ONS dá tensões em pu sobre uma base fixa (230, 500 kV…). '
              'Para ajustar 25/59/27 e religamento no relé, converta para a base real do TP — '
              'usar o pu direto sobre a tensão do TP é o erro mais comum em campo.',
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
}
