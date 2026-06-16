import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/utils/instrument_transformers.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class RtcRtpScreen extends StatefulWidget {
  const RtcRtpScreen({super.key});

  @override
  State<RtcRtpScreen> createState() => _RtcRtpScreenState();
}

class _RtcRtpScreenState extends State<RtcRtpScreen> {
  int _mode = 0; // 0 = TC (corrente), 1 = TP (tensão)

  final _primaryNom = TextEditingController(text: '600');
  final _secondaryNom = TextEditingController(text: '5');
  final _primaryVal = TextEditingController(text: '480');
  final _secondaryVal = TextEditingController(text: '4');

  List<ToolResult>? _results;
  String? _warning;

  bool get _isTc => _mode == 0;
  String get _unit => _isTc ? 'A' : 'kV';
  String get _ratioLabel => _isTc ? 'RTC' : 'RTP';

  @override
  void dispose() {
    for (final c in [_primaryNom, _secondaryNom, _primaryVal, _secondaryVal]) {
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
    final pn = _p(_primaryNom);
    final sn = _p(_secondaryNom);
    if (pn == null || sn == null || pn <= 0 || sn <= 0) {
      setState(() {
        _warning = 'Informe os valores nominais (primário e secundário) maiores que zero.';
        _results = null;
      });
      return;
    }
    final ratio = transformRatio(pn, sn);
    final results = <ToolResult>[
      ToolResult(_ratioLabel, '${fmtNumber(ratio, decimals: 3)}  ($pn$_unit : $sn$_unit)'),
    ];

    final pv = _p(_primaryVal);
    if (pv != null) {
      results.add(ToolResult(
        'Valor no secundário (de $pv$_unit no primário)',
        '${fmtNumber(secondaryFromPrimary(pv, ratio), decimals: 4)} $_unit',
      ));
    }
    final sv = _p(_secondaryVal);
    if (sv != null) {
      results.add(ToolResult(
        'Valor no primário (de $sv$_unit no secundário)',
        '${fmtNumber(primaryFromSecondary(sv, ratio), decimals: 3)} $_unit',
      ));
    }

    setState(() {
      _warning = null;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryWord = _isTc ? 'corrente' : 'tensão';
    return ToolPage(
      title: 'RTC / RTP',
      children: [
        ToolSegmented(
          labels: const ['TC (corrente)', 'TP (tensão)'],
          selected: _mode,
          onSelect: (i) => setState(() {
            _mode = i;
            _results = null;
            _warning = null;
          }),
        ),
        const SizedBox(height: 16),
        ToolCard(
          title: _isTc
              ? 'Transformador de Corrente'
              : 'Transformador de Potencial',
          subtitle:
              '$_ratioLabel = ${primaryWord}_primária_nominal / ${primaryWord}_secundária_nominal',
          children: [
            ToolFieldRow(children: [
              ToolField(
                controller: _primaryNom,
                label: 'Primário nominal ($_unit)',
                semantic: 'Valor nominal no primário',
              ),
              ToolField(
                controller: _secondaryNom,
                label: 'Secundário nominal ($_unit)',
                semantic: 'Valor nominal no secundário',
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.rtcRtpConversions,
          children: [
            ToolField(
              controller: _primaryVal,
              label: 'Valor medido no primário ($_unit)',
              semantic: 'Valor medido no primário',
            ),
            const SizedBox(height: 12),
            ToolField(
              controller: _secondaryVal,
              label: 'Valor medido no secundário ($_unit)',
              semantic: 'Valor medido no secundário',
            ),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
          ),
        ],
      ],
    );
  }
}
