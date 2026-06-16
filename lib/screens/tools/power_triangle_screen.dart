import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/utils/power_triangle.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class PowerTriangleScreen extends StatefulWidget {
  const PowerTriangleScreen({super.key});

  @override
  State<PowerTriangleScreen> createState() => _PowerTriangleScreenState();
}

class _PowerTriangleScreenState extends State<PowerTriangleScreen> {
  int _mode = 0; // 0 = P e FP, 1 = P e Q, 2 = S e FP

  final _a = TextEditingController(text: '100');
  final _b = TextEditingController(text: '0.85');

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _setMode(int i) {
    setState(() {
      _mode = i;
      _results = null;
      _warning = null;
      switch (i) {
        case 0:
          _a.text = '100';
          _b.text = '0.85';
          break;
        case 1:
          _a.text = '100';
          _b.text = '60';
          break;
        case 2:
          _a.text = '120';
          _b.text = '0.85';
          break;
      }
    });
  }

  void _calculate() {
    final a = _p(_a);
    final b = _p(_b);
    if (a == null || b == null) {
      setState(() {
        _warning = 'Preencha os dois valores.';
        _results = null;
      });
      return;
    }
    if ((_mode == 0 || _mode == 2) && (b <= 0 || b > 1)) {
      setState(() {
        _warning = 'O fator de potência deve estar entre 0 e 1.';
        _results = null;
      });
      return;
    }

    PowerTriangle t;
    if (_mode == 0) {
      t = triangleFromActiveAndPf(a, b);
    } else if (_mode == 1) {
      t = triangleFromActiveAndReactive(a, b);
    } else {
      t = triangleFromApparentAndPf(a, b);
    }

    setState(() {
      _warning = null;
      _results = [
        ToolResult(AppLocalizations.of(context)!.powerTrianglePActive, '${fmtNumber(t.activeKw, decimals: 2)} kW'),
        ToolResult(AppLocalizations.of(context)!.powerTriangleQReactive, '${fmtNumber(t.reactiveKvar, decimals: 2)} kvar'),
        ToolResult(AppLocalizations.of(context)!.powerTriangleSApparent, '${fmtNumber(t.apparentKva, decimals: 2)} kVA'),
        ToolResult(AppLocalizations.of(context)!.powerTrianglePF, fmtNumber(t.powerFactor, decimals: 4)),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final labelA = _mode == 2 ? 'S (kVA)' : 'P (kW)';
    final labelB = _mode == 1 ? 'Q (kvar)' : AppLocalizations.of(context)!.powerTrianglePF;
    return ToolPage(
      title: 'Triângulo de Potências',
      children: [
        ToolSegmented(
          labels: const ['P e FP', 'P e Q', 'S e FP'],
          selected: _mode,
          onSelect: _setMode,
        ),
        const SizedBox(height: 16),
        ToolCard(
          title: AppLocalizations.of(context)!.powerTriangleInputs,
          subtitle: 'S = √(P² + Q²) · P = S·cosφ · Q = S·senφ',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _a, label: labelA),
              ToolField(controller: _b, label: labelB),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: _results ?? const [], warning: _warning),
        ],
      ],
    );
  }
}
