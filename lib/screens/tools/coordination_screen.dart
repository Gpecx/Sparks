import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/idmt_curves.dart';
import 'package:spark_app/utils/coordination.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';
import 'package:spark_app/screens/tools/widgets/idmt_curve_picker.dart';

class _RelaySettings {
  final String name;
  IdmtCurve curve;
  final TextEditingController pickup;
  final TextEditingController dial;

  _RelaySettings({
    required this.name,
    required this.curve,
    required String pickup,
    required String dial,
  })  : pickup = TextEditingController(text: pickup),
        dial = TextEditingController(text: dial);

  void dispose() {
    pickup.dispose();
    dial.dispose();
  }
}

class CoordinationScreen extends StatefulWidget {
  const CoordinationScreen({super.key});

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  late final _main = _RelaySettings(
    name: 'Relé principal (jusante)',
    curve: idmtCurves.first,
    pickup: '100',
    dial: '0.1',
  );
  late final _backup = _RelaySettings(
    name: 'Relé de retaguarda (montante)',
    curve: idmtCurves.first,
    pickup: '100',
    dial: '0.3',
  );

  final _fault = TextEditingController(text: '1000');
  final _cti = TextEditingController(text: '0.3');

  List<ToolResult>? _results;
  String? _warning;
  bool _coordinated = false;

  @override
  void dispose() {
    _main.dispose();
    _backup.dispose();
    _fault.dispose();
    _cti.dispose();
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  Future<void> _pick(_RelaySettings r) async {
    final selected = await showIdmtCurvePicker(context, selectedId: r.curve.id);
    if (selected != null) setState(() => r.curve = selected);
  }

  void _calculate() {
    final ifault = _p(_fault);
    final cti = _p(_cti);
    final pkMain = _p(_main.pickup);
    final tdMain = _p(_main.dial);
    final pkBack = _p(_backup.pickup);
    final tdBack = _p(_backup.dial);
    if ([ifault, cti, pkMain, tdMain, pkBack, tdBack].any((e) => e == null) ||
        ifault! <= 0 || pkMain! <= 0 || pkBack! <= 0 || tdMain! <= 0 || tdBack! <= 0) {
      setState(() {
        _warning = 'Preencha curva, pickup e dial dos dois relés, a corrente de falta e o CTI.';
        _results = null;
      });
      return;
    }
    if (ifault <= pkMain || ifault <= pkBack) {
      setState(() {
        _warning = 'A corrente de falta deve ser maior que os pickups dos dois relés.';
        _results = null;
      });
      return;
    }

    final tMain = _main.curve.timeForMultiple(ifault / pkMain, tdMain);
    final tBack = _backup.curve.timeForMultiple(ifault / pkBack, tdBack);
    final r = coordinationCheck(
      timeMain: tMain,
      timeBackup: tBack,
      requiredCti: cti!,
    );

    setState(() {
      _warning = null;
      _coordinated = r.coordinated;
      _results = [
        ToolResult(AppLocalizations.of(context)!.coordMainTime, '${fmtNumber(r.timeMain, decimals: 3)} s'),
        ToolResult(AppLocalizations.of(context)!.coordBackupTime, '${fmtNumber(r.timeBackup, decimals: 3)} s'),
        ToolResult(AppLocalizations.of(context)!.coordCtiReal, '${fmtNumber(r.interval, decimals: 3)} s'),
        ToolResult(AppLocalizations.of(context)!.coordCtiMinShort, '${fmtNumber(cti, decimals: 3)} s'),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: AppLocalizations.of(context)!.tlCoordination,
      children: [
        _relayCard(_main),
        const SizedBox(height: 12),
        _relayCard(_backup),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.coordFaultMargin,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _fault, label: AppLocalizations.of(context)!.coordFault),
              ToolField(controller: _cti, label: AppLocalizations.of(context)!.coordCtiMin),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: AppLocalizations.of(context)!.tlBtnCalculate, onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          if (_results != null) _verdict(),
          if (_results != null) const SizedBox(height: 12),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
            title: AppLocalizations.of(context)!.coordCoord,
          ),
        ],
      ],
    );
  }

  Widget _relayCard(_RelaySettings r) {
    return ToolCard(
      title: r.name,
      children: [
        Semantics(
          button: true,
          label: 'Curva: ${r.curve.name}. Toque para trocar.',
          child: GestureDetector(
            onTap: () => _pick(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.show_chart,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.curve.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.unfold_more,
                      color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ToolFieldRow(children: [
          ToolField(controller: r.pickup, label: AppLocalizations.of(context)!.coordPickup),
          ToolField(controller: r.dial, label: AppLocalizations.of(context)!.coordDial),
        ]),
      ],
    );
  }

  Widget _verdict() {
    final color = _coordinated ? AppColors.primary : AppColors.error;
    final icon = _coordinated ? Icons.check_circle : Icons.warning_amber_rounded;
    final text = _coordinated
        ? 'COORDENADO — a margem atende ao CTI mínimo.'
        : 'NÃO COORDENADO — a margem é menor que o CTI mínimo.';
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
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
