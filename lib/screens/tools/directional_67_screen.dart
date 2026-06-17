import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/directional_67.dart';
import 'package:spark_app/utils/idmt_curves.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';
import 'package:spark_app/screens/tools/widgets/idmt_curve_picker.dart';

class Directional67Screen extends StatefulWidget {
  const Directional67Screen({super.key});

  @override
  State<Directional67Screen> createState() => _Directional67ScreenState();
}

class _Directional67ScreenState extends State<Directional67Screen> {
  int _mode = 0; // 0 = 67 (fase), 1 = 67N (neutro)
  int _polKind = 0; // 67N: 0 = 3V0, 1 = 3I0
  CharacteristicType _char = CharacteristicType.definiteTime;
  DirectionMode _direction = DirectionMode.forward;
  FaultType _faultType = FaultType.phaseToNeutral;
  IdmtCurve _idmtCurve = idmtCurves.first;

  /// Fase protegida pelo elemento 67 (modo trifásico). Define qual quadratura.
  ProtectedPhase _phase = ProtectedPhase.a;

  /// Modo de entrada da polarização no 67 fase.
  /// 0 = Trifásico (digita VA, VB, VC e o sistema calcula V_pol)
  /// 1 = Direto (digita V_pol módulo e ângulo)
  int _inputMode = 0;

  // Defaults para um sistema balanceado ABC com falta na fase A (X/R≈1).
  final _iOpMag = TextEditingController(text: '5');
  final _iOpAng = TextEditingController(text: '-45');
  final _polMag = TextEditingController(text: '173.21');
  final _polAng = TextEditingController(text: '-90');
  final _mta = TextEditingController(text: '45');
  final _sector = TextEditingController(text: '180');
  final _pickup = TextEditingController(text: '1');
  final _tdMs = TextEditingController(text: '100');
  final _td = TextEditingController(text: '0.10');

  // Tensões trifásicas para o modo "trifásico" (defaults: sistema balanceado).
  final _vaMag = TextEditingController(text: '100');
  final _vaAng = TextEditingController(text: '0');
  final _vbMag = TextEditingController(text: '100');
  final _vbAng = TextEditingController(text: '-120');
  final _vcMag = TextEditingController(text: '100');
  final _vcAng = TextEditingController(text: '120');

  List<TextEditingController> get _allControllers => [
        _iOpMag, _iOpAng, _polMag, _polAng, _mta, _sector, _pickup, _tdMs, _td,
        _vaMag, _vaAng, _vbMag, _vbAng, _vcMag, _vcAng,
      ];

  @override
  void initState() {
    super.initState();
    for (final c in _allControllers) {
      c.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.removeListener(_onChange);
      c.dispose();
    }
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _onMode(int i) {
    setState(() {
      _mode = i;
      if (i == 1) {
        _mta.text = '-45';
        _iOpAng.text = '135';
        _polAng.text = '180';
        _pickup.text = '0.5';
      } else {
        _mta.text = '45';
        _iOpAng.text = '45';
        _polAng.text = '0';
        _pickup.text = '1';
      }
    });
  }

  void _applyRecommendedMta() {
    final mta = recommendedMta(faultType: _faultType, isNeutral: _mode == 1);
    setState(() => _mta.text = mta.toStringAsFixed(0));
  }

  String get _opLabel => _mode == 0 ? 'I${_phase.label}' : '3I0';
  String get _polLabel {
    if (_mode == 0) {
      return _inputMode == 0
          ? '${_phase.polarizationFormula} (quadratura)'
          : 'V polarização (quadratura)';
    }
    return _polKind == 0 ? '3V0 (tensão residual)' : '3I0 polarização (corrente)';
  }

  bool get _useTrifasico => _mode == 0 && _inputMode == 0;

  /// Calcula a polarização efetiva (mag, ang) que será usada na avaliação.
  /// Em modo trifásico: aplica a quadratura V_PA / V_PB / V_PC.
  /// Em modo direto: usa os campos _polMag / _polAng.
  ({double mag, double ang})? _effectivePolarization() {
    if (_useTrifasico) {
      final va = _p(_vaMag), aa = _p(_vaAng);
      final vb = _p(_vbMag), ab = _p(_vbAng);
      final vc = _p(_vcMag), ac = _p(_vcAng);
      if (va == null || aa == null || vb == null || ab == null || vc == null || ac == null) {
        return null;
      }
      if (va < 0 || vb < 0 || vc < 0) return null;
      return quadraturePolarization(
        phase: _phase,
        va: va, angVa: aa,
        vb: vb, angVb: ab,
        vc: vc, angVc: ac,
      );
    }
    final pm = _p(_polMag), pa = _p(_polAng);
    if (pm == null || pa == null || pm <= 0) return null;
    return (mag: pm, ang: pa);
  }

  Directional67Result? _compute() {
    final iom = _p(_iOpMag);
    final ioa = _p(_iOpAng);
    final pol = _effectivePolarization();
    final mta = _p(_mta);
    final sec = _p(_sector);
    final pk = _p(_pickup);
    if (iom == null || ioa == null || pol == null ||
        mta == null || sec == null || pk == null) {
      return null;
    }
    if (iom < 0 || pol.mag <= 0 || pk < 0 || sec <= 0 || sec > 360) {
      return null;
    }
    final dtMs = _p(_tdMs) ?? 100.0;
    final td = _p(_td) ?? 0.1;
    return evaluate67(
      characteristic: _char,
      idmtCurve: _char == CharacteristicType.idmt ? _idmtCurve : null,
      td: td,
      definiteTimeMs: dtMs,
      direction: _direction,
      mta: mta,
      sectorOpening: sec,
      pickup: pk,
      iOpMag: iom,
      iOpAng: ioa,
      polMag: pol.mag,
      polAng: pol.ang,
    );
  }

  String? _validationWarning() {
    final pol = _effectivePolarization();
    if (_p(_iOpMag) == null ||
        _p(_iOpAng) == null ||
        pol == null ||
        _p(_mta) == null ||
        _p(_sector) == null ||
        _p(_pickup) == null) {
      return _useTrifasico
          ? 'Preencha operação, V_A/V_B/V_C, MTA, abertura do setor e pickup.'
          : 'Preencha operação, polarização, MTA, abertura do setor e pickup.';
    }
    if (pol.mag <= 0) {
      return _useTrifasico
          ? 'Tensões trifásicas insuficientes — polarização ficou 0 (sistema sem desequilíbrio?).'
          : 'Polarização deve ser > 0.';
    }
    final sec = _p(_sector) ?? 0;
    if (sec <= 0 || sec > 360) {
      return 'Abertura do setor deve estar entre 1° e 360°.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    final warning = _validationWarning();

    return ToolPage(
      title: AppLocalizations.of(context)!.tlDirectional,
      children: [
        _infoBox(),
        const SizedBox(height: 12),
        ToolSegmented(
          labels: const ['67 (fase)', '67N (neutro)'],
          selected: _mode,
          onSelect: _onMode,
        ),
        if (_mode == 1) ...[
          const SizedBox(height: 12),
          ToolCard(
            title: AppLocalizations.of(context)!.dir67PolN,
            children: [
              ToolSegmented(
                labels: const ['Por 3V0 (tensão)', 'Por 3I0 (corrente)'],
                selected: _polKind,
                onSelect: (i) => setState(() => _polKind = i),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.dir67OpMagnitude,
          subtitle: AppLocalizations.of(context)!.tlDirModAng(_opLabel),
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _iOpMag, label: AppLocalizations.of(context)!.tlOpAmps(_opLabel)),
              ToolField(controller: _iOpAng, label: AppLocalizations.of(context)!.dir67Ang, signed: true),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        if (_mode == 0) _phaseAndModeCard(),
        if (_mode == 0) const SizedBox(height: 12),
        if (_useTrifasico) ...[
          _trifasicoVoltagesCard(),
          const SizedBox(height: 12),
          _polarizationMemorialCard(),
        ] else
          ToolCard(
            title: AppLocalizations.of(context)!.dir67Polarization,
            subtitle: _polLabel,
            children: [
              ToolFieldRow(children: [
                ToolField(controller: _polMag, label: AppLocalizations.of(context)!.dir67Mod),
                ToolField(controller: _polAng, label: AppLocalizations.of(context)!.dir67Ang, signed: true),
              ]),
            ],
          ),
        const SizedBox(height: 12),
        _faultTypeCard(),
        const SizedBox(height: 12),
        _directionalCard(),
        const SizedBox(height: 12),
        _characteristicCard(),
        const SizedBox(height: 20),
        if (warning != null) ...[
          ToolResultsPanel(results: const [], warning: warning),
          const SizedBox(height: 12),
        ],
        if (result != null) ...[
          _phasorCard(result),
          const SizedBox(height: 16),
          _verdictBox(result),
          const SizedBox(height: 12),
          _resultsPanel(result),
        ],
      ],
    );
  }

  Widget _phaseAndModeCard() {
    return ToolCard(
      title: AppLocalizations.of(context)!.dir67Phase,
      subtitle:
          AppLocalizations.of(context)!.dir67PolDesc,
      children: [
        Row(
          children: [
            const Text(
              'Fase:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ToolSegmented(
                labels: const ['A', 'B', 'C'],
                selected: _phase == ProtectedPhase.a
                    ? 0
                    : _phase == ProtectedPhase.b
                        ? 1
                        : 2,
                onSelect: (i) => setState(() {
                  _phase = i == 0
                      ? ProtectedPhase.a
                      : i == 1
                          ? ProtectedPhase.b
                          : ProtectedPhase.c;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ToolSegmented(
          labels: const ['Trifásico (V_A,V_B,V_C)', 'Direto (V_pol)'],
          selected: _inputMode,
          onSelect: (i) => setState(() => _inputMode = i),
        ),
        const SizedBox(height: 6),
        Text(
          _inputMode == 0
              ? 'O sistema calcula V_pol automaticamente via quadratura.'
              : 'Você digita V_pol já calculado.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _trifasicoVoltagesCard() {
    return ToolCard(
      title: AppLocalizations.of(context)!.dir67Volt,
      subtitle:
          AppLocalizations.of(context)!.dir67VoltDesc,
      children: [
        ToolFieldRow(children: [
          ToolField(controller: _vaMag, label: AppLocalizations.of(context)!.dir67Va),
          ToolField(controller: _vaAng, label: AppLocalizations.of(context)!.dir67VaAng, signed: true),
        ]),
        const SizedBox(height: 8),
        ToolFieldRow(children: [
          ToolField(controller: _vbMag, label: AppLocalizations.of(context)!.dir67Vb),
          ToolField(controller: _vbAng, label: AppLocalizations.of(context)!.dir67VbAng, signed: true),
        ]),
        const SizedBox(height: 8),
        ToolFieldRow(children: [
          ToolField(controller: _vcMag, label: AppLocalizations.of(context)!.dir67Vc),
          ToolField(controller: _vcAng, label: AppLocalizations.of(context)!.dir67VcAng, signed: true),
        ]),
      ],
    );
  }

  Widget _polarizationMemorialCard() {
    final pol = _effectivePolarization();
    final formula = _phase.polarizationFormula;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.functions,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.dir67PolCalc,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formula,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pol != null
                ? 'V_pol = ${pol.mag.toStringAsFixed(2)} V  ∠  ${pol.ang.toStringAsFixed(1)}°'
                : 'V_pol = (incompleto)',
            style: TextStyle(
              color: pol != null
                  ? AppColors.textSecondary
                  : AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Em FP=1, V_pol fica 90° atrás de V_fase (daí "quadratura"). '
            'Durante falta na própria fase, as outras duas continuam sãs — '
            'a polarização permanece estável.',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _faultTypeCard() {
    final recMta = recommendedMta(faultType: _faultType, isNeutral: _mode == 1);
    return ToolCard(
      title: AppLocalizations.of(context)!.dir67FaultType,
      subtitle: AppLocalizations.of(context)!.dir67PolNDesc,
      children: [
        ToolSegmented(
          labels: const ['Fase-Neutro (F-N)', 'Fase-Fase (F-F)'],
          selected: _faultType == FaultType.phaseToNeutral ? 0 : 1,
          onSelect: (i) => setState(() {
            _faultType = i == 0 ? FaultType.phaseToNeutral : FaultType.phaseToPhase;
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'MTA recomendado: ${recMta.toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _applyRecommendedMta,
              icon: const Icon(Icons.tune, size: 16),
              label: Text(AppLocalizations.of(context)!.dir67Apply),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _directionalCard() {
    return ToolCard(
      title: AppLocalizations.of(context)!.dir67Adjust,
      subtitle: AppLocalizations.of(context)!.dir67AdjustDesc,
      children: [
        ToolSegmented(
          labels: const ['Forward (direta)', 'Reverse (reversa)', 'Não direcional'],
          selected: _direction == DirectionMode.forward
              ? 0
              : _direction == DirectionMode.reverse
                  ? 1
                  : 2,
          onSelect: (i) => setState(() {
            _direction = i == 0
                ? DirectionMode.forward
                : i == 1
                    ? DirectionMode.reverse
                    : DirectionMode.nonDirectional;
          }),
        ),
        const SizedBox(height: 12),
        ToolFieldRow(children: [
          ToolField(controller: _mta, label: AppLocalizations.of(context)!.dir67Mta, signed: true),
          ToolField(controller: _sector, label: AppLocalizations.of(context)!.dir67Aperture),
        ]),
      ],
    );
  }

  Widget _characteristicCard() {
    return ToolCard(
      title: AppLocalizations.of(context)!.dir67TimeChar,
      subtitle: AppLocalizations.of(context)!.dir67TimeDef,
      children: [
        ToolSegmented(
          labels: const ['Definite Time', 'IDMT'],
          selected: _char == CharacteristicType.definiteTime ? 0 : 1,
          onSelect: (i) => setState(() {
            _char = i == 0 ? CharacteristicType.definiteTime : CharacteristicType.idmt;
          }),
        ),
        const SizedBox(height: 12),
        ToolFieldRow(children: [
          ToolField(controller: _pickup, label: AppLocalizations.of(context)!.dir67Ipickup),
          if (_char == CharacteristicType.definiteTime)
            ToolField(controller: _tdMs, label: AppLocalizations.of(context)!.dir67Tms)
          else
            ToolField(controller: _td, label: AppLocalizations.of(context)!.dir67Td),
        ]),
        if (_char == CharacteristicType.idmt) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final c = await showIdmtCurvePicker(context, selectedId: _idmtCurve.id);
              if (c != null) setState(() => _idmtCurve = c);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.show_chart, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _idmtCurve.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _idmtCurve.family,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _verdictBox(Directional67Result r) {
    final color = r.operates
        ? AppColors.primary
        : (r.abovePickup ? AppColors.warning : AppColors.gold);
    return Container(
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
              Icon(
                r.operates
                    ? Icons.bolt
                    : (r.abovePickup ? Icons.block : Icons.warning_amber),
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.verdict,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (r.operatingTimeMs != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                'Tempo de atuação: ${r.operatingTimeMs!.toStringAsFixed(0)} ms (${(r.operatingTimeMs! / 1000.0).toStringAsFixed(3)} s)',
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultsPanel(Directional67Result r) {
    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.dir67Theta, '${fmtNumber(r.relativeAngle, decimals: 1)}°'),
      ToolResult(AppLocalizations.of(context)!.dir67ThetaMta, '${fmtNumber(r.torqueAngle, decimals: 1)}°'),
      ToolResult(AppLocalizations.of(context)!.dir67MarginAng, '${fmtNumber(r.angularMargin, decimals: 1)}°'),
      ToolResult(AppLocalizations.of(context)!.dir67InSectorFwd, r.inForwardSector ? 'Sim' : 'Não'),
      ToolResult(AppLocalizations.of(context)!.dir67InSector, r.inSelectedSector ? 'Sim' : 'Não'),
      ToolResult(AppLocalizations.of(context)!.dir67AbovePkp, r.abovePickup ? 'Sim' : 'Não'),
      if (r.operatingTimeMs != null)
        ToolResult(AppLocalizations.of(context)!.dir67TimeAtuate, '${r.operatingTimeMs!.toStringAsFixed(0)} ms'),
    ];
    return ToolResultsPanel(
      results: results,
      title: AppLocalizations.of(context)!.dir67Eval,
      note: r.reason,
    );
  }

  Widget _phasorCard(Directional67Result r) {
    final mta = _p(_mta) ?? 0;
    final sector = _p(_sector) ?? 180;
    final iOpAng = _p(_iOpAng) ?? 0;
    final iOpMag = _p(_iOpMag) ?? 0;
    final pol = _effectivePolarization();
    final polAng = pol?.ang ?? (_p(_polAng) ?? 0);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              AppLocalizations.of(context)!.dir67Phasor,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _PhasorPainter(
                polAngle: polAng,
                opAngle: iOpAng,
                iOpMag: iOpMag,
                mta: mta,
                sectorOpening: sector,
                direction: _direction,
                operates: r.operates,
                inSelectedSector: r.inSelectedSector,
                opLabel: _opLabel,
                theta: r.relativeAngle,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legend(AppColors.primary, 'Polarização'),
              _legend(AppColors.gold, _opLabel),
              _legend(AppColors.textMuted, 'Linha MTA'),
              _legend(AppColors.primary.withValues(alpha: 0.25), 'Setor de operação'),
              if (_direction == DirectionMode.reverse)
                _legend(AppColors.warning.withValues(alpha: 0.25), 'Setor reverso'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
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
          const Icon(Icons.explore_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.dir67TimeDesc,
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

class _PhasorPainter extends CustomPainter {
  final double polAngle;
  final double opAngle;
  final double iOpMag;
  final double mta;
  final double sectorOpening;
  final DirectionMode direction;
  final bool operates;
  final bool inSelectedSector;
  final String opLabel;
  /// θ = ∠Iop − ∠V_pol normalizado, em (−180, 180].
  final double theta;

  _PhasorPainter({
    required this.polAngle,
    required this.opAngle,
    required this.iOpMag,
    required this.mta,
    required this.sectorOpening,
    required this.direction,
    required this.operates,
    required this.inSelectedSector,
    required this.opLabel,
    required this.theta,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Margem maior para acomodar rótulos angulares fora do círculo.
    const margin = 30.0;
    final c = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - margin;

    Offset dir(double deg) {
      final rad = deg * math.pi / 180.0;
      return Offset(math.cos(rad), -math.sin(rad));
    }

    void drawSector(double mtaAbs, double opening, Color color) {
      final half = opening / 2.0;
      final start = mtaAbs - half;
      final path = Path()..moveTo(c.dx, c.dy);
      const steps = 120;
      for (int i = 0; i <= steps; i++) {
        final a = start + opening * i / steps;
        final p = c + dir(a) * radius;
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // Fundo do círculo
    canvas.drawCircle(c, radius,
        Paint()..color = AppColors.background.withValues(alpha: 0.4));

    final mtaForward = polAngle + mta;
    final mtaReverse = mtaForward + 180.0;

    // Setor forward sempre desenhado
    drawSector(mtaForward, sectorOpening,
        AppColors.primary.withValues(alpha: 0.22));

    // Setor reverso quando usuário selecionou Reverse
    if (direction == DirectionMode.reverse) {
      drawSector(mtaReverse, sectorOpening,
          AppColors.warning.withValues(alpha: 0.18));
    }

    // Grid intermediário a 25%, 50%, 75% do raio
    final gridPaint = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final f in [0.25, 0.5, 0.75]) {
      canvas.drawCircle(c, radius * f, gridPaint);
    }

    // Linhas radiais a cada 30° (referência polar)
    for (int a = 0; a < 360; a += 30) {
      final p1 = c + dir(a.toDouble()) * radius * 0.97;
      final p2 = c + dir(a.toDouble()) * radius;
      canvas.drawLine(
        p1, p2,
        Paint()
          ..color = AppColors.cardBorder.withValues(alpha: 0.5)
          ..strokeWidth = 0.8,
      );
    }

    // Eixos cardinais (mais grossos)
    final axis = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(c.dx - radius, c.dy), Offset(c.dx + radius, c.dy), axis);
    canvas.drawLine(
        Offset(c.dx, c.dy - radius), Offset(c.dx, c.dy + radius), axis);

    // Borda do círculo
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = AppColors.cardBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // ── Rótulos angulares cardinais ────────────────────────────────
    _drawText(canvas, '0°',
        c + Offset(radius + 12, 0), AppColors.textMuted, 11,
        anchor: _Anchor.left);
    _drawText(canvas, '+90°',
        c + Offset(0, -radius - 12), AppColors.textMuted, 11,
        anchor: _Anchor.center);
    _drawText(canvas, '±180°',
        c + Offset(-radius - 12, 0), AppColors.textMuted, 11,
        anchor: _Anchor.right);
    _drawText(canvas, '−90°',
        c + Offset(0, radius + 12), AppColors.textMuted, 11,
        anchor: _Anchor.center);

    // Rótulos intermediários (45°, 135°, −45°, −135°)
    for (final ang in [45, 135, -45, -135]) {
      final p = c + dir(ang.toDouble()) * (radius + 16);
      _drawText(canvas, '${ang > 0 ? '+' : ''}$ang°', p,
          AppColors.textMuted.withValues(alpha: 0.7), 9,
          anchor: _Anchor.center);
    }

    // ── Linha MTA com rótulo ────────────────────────────────────────
    final mtaLineColor = AppColors.textSecondary.withValues(alpha: 0.85);
    canvas.drawLine(
      c,
      c + dir(mtaForward) * radius,
      Paint()
        ..color = mtaLineColor
        ..strokeWidth = 1.8,
    );
    // Linha MTA reverso (tracejada)
    _dashedLine(canvas, c, c + dir(mtaReverse) * radius,
        AppColors.textMuted.withValues(alpha: 0.4));

    // Rótulo "MTA = X°" perto da linha MTA, a ~55% do raio
    final mtaLabelPos = c + dir(mtaForward) * radius * 0.55;
    final mtaText = 'MTA ${mta.toStringAsFixed(0)}°';
    _drawLabelChip(
      canvas,
      mtaText,
      mtaLabelPos,
      bg: AppColors.background.withValues(alpha: 0.85),
      fg: AppColors.textPrimary,
      border: mtaLineColor,
      fontSize: 10,
    );

    // ── Arco do ângulo θ entre V_pol e I_op ────────────────────────
    // O arco sai de V_pol e vai até a direção de I_op no menor caminho.
    // Cor vermelha para destacar — é o ângulo-chave da decisão direcional.
    if (theta.abs() > 1.0) {
      final arcRadius = radius * 0.22;
      const steps = 36;
      final arcPath = Path();
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final a = polAngle + theta * t;
        final p = c + dir(a) * arcRadius;
        if (i == 0) {
          arcPath.moveTo(p.dx, p.dy);
        } else {
          arcPath.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        arcPath,
        Paint()
          ..color = AppColors.error
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      // Pequena seta no fim do arco
      final tailAngle = polAngle + theta;
      final tip = c + dir(tailAngle) * arcRadius;
      const tickLen = 5.0;
      final tipDir = dir(tailAngle);
      final tangential = Offset(-tipDir.dy, tipDir.dx) * (theta >= 0 ? 1.0 : -1.0);
      final t1 = tip + tangential * tickLen - tipDir * 2;
      canvas.drawLine(tip, t1,
          Paint()..color = AppColors.error..strokeWidth = 2.0);

      // Label "θ = X°" no centro do arco
      final midAngle = polAngle + theta / 2.0;
      final labelPos = c + dir(midAngle) * arcRadius * 1.5;
      _drawLabelChip(
        canvas,
        'θ = ${theta.toStringAsFixed(0)}°',
        labelPos,
        bg: AppColors.background.withValues(alpha: 0.9),
        fg: AppColors.error,
        border: AppColors.error,
        fontSize: 10,
      );
    }

    // ── Fasores principais ─────────────────────────────────────────
    // Polarização (verde)
    _arrow(canvas, c, c + dir(polAngle) * radius * 0.92,
        AppColors.primary, 2.8);
    _drawLabelChip(
      canvas,
      'V_pol ${polAngle.toStringAsFixed(0)}°',
      c + dir(polAngle) * radius * 0.6,
      bg: AppColors.primary.withValues(alpha: 0.15),
      fg: AppColors.primary,
      border: AppColors.primary,
      fontSize: 10,
    );

    // Operação (dourado/laranja conforme estado)
    final opColor = operates
        ? AppColors.gold
        : (inSelectedSector
            ? AppColors.gold.withValues(alpha: 0.75)
            : AppColors.warning);
    final opEnd = c + dir(opAngle) * radius * 0.78;
    _arrow(canvas, c, opEnd, opColor, 2.8);

    // ── PONTO DE TESTE (marcador) ──────────────────────────────────
    // Círculo destacado na ponta do fasor de operação
    canvas.drawCircle(
        opEnd, 7, Paint()..color = opColor.withValues(alpha: 0.95));
    canvas.drawCircle(
      opEnd,
      7,
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Label do ponto de teste com magnitude e ângulo
    _drawLabelChip(
      canvas,
      '$opLabel ${iOpMag.toStringAsFixed(2)} ∠ ${opAngle.toStringAsFixed(0)}°',
      opEnd + _labelOffsetFor(opAngle),
      bg: opColor.withValues(alpha: 0.15),
      fg: opColor,
      border: opColor,
      fontSize: 10,
    );

    // ── Indicador de status do ponto de teste no canto ─────────────
    _drawStatusBadge(canvas, size);
  }

  /// Offset para colocar o label do ponto de teste sem sobrepor o fasor.
  /// O label sai perpendicular ao fasor, do lado de fora.
  Offset _labelOffsetFor(double angDeg) {
    final rad = angDeg * math.pi / 180.0;
    // perpendicular (rotação de +90°): (cos+90, -sin+90) = (-sin, -cos)
    return Offset(-math.sin(rad) * 18, -math.cos(rad) * 18);
  }

  void _drawStatusBadge(Canvas canvas, Size size) {
    final txt = operates
        ? 'TRIP'
        : (inSelectedSector ? 'NO TRIP' : 'BLOQUEIA');
    final color = operates
        ? AppColors.primary
        : (inSelectedSector ? AppColors.warning : AppColors.gold);
    const pad = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    final tp = TextPainter(
      text: TextSpan(
        text: txt,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = tp.width + pad.horizontal;
    final h = tp.height + pad.vertical;
    final rect = Rect.fromLTWH(8, 8, w, h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    tp.paint(canvas, Offset(rect.left + pad.left, rect.top + pad.top));
  }

  void _drawLabelChip(
    Canvas canvas,
    String text,
    Offset center, {
    required Color bg,
    required Color fg,
    required Color border,
    double fontSize = 10,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padH = 6.0;
    const padV = 3.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = bg);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    tp.paint(canvas, Offset(rect.left + padH, rect.top + padV));
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos,
    Color color,
    double fontSize, {
    _Anchor anchor = _Anchor.center,
    FontWeight weight = FontWeight.w600,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    Offset offset;
    switch (anchor) {
      case _Anchor.center:
        offset = Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2);
        break;
      case _Anchor.left:
        offset = Offset(pos.dx, pos.dy - tp.height / 2);
        break;
      case _Anchor.right:
        offset = Offset(pos.dx - tp.width, pos.dy - tp.height / 2);
        break;
    }
    tp.paint(canvas, offset);
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color, double w) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final ux = d.dx / len, uy = d.dy / len;
    const head = 10.0;
    final left = Offset(
        to.dx - head * (ux * math.cos(0.5) - uy * math.sin(0.5)),
        to.dy - head * (uy * math.cos(0.5) + ux * math.sin(0.5)));
    final right = Offset(
        to.dx - head * (ux * math.cos(-0.5) - uy * math.sin(-0.5)),
        to.dy - head * (uy * math.cos(-0.5) + ux * math.sin(-0.5)));
    canvas.drawLine(to, left, paint);
    canvas.drawLine(to, right, paint);
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    const dash = 6.0, gap = 4.0;
    final total = (to - from).distance;
    if (total == 0) return;
    final ux = (to.dx - from.dx) / total, uy = (to.dy - from.dy) / total;
    double d = 0;
    while (d < total) {
      final s = from + Offset(ux * d, uy * d);
      final e = from +
          Offset(ux * math.min(d + dash, total), uy * math.min(d + dash, total));
      canvas.drawLine(s, e, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_PhasorPainter old) =>
      old.polAngle != polAngle ||
      old.opAngle != opAngle ||
      old.iOpMag != iOpMag ||
      old.mta != mta ||
      old.sectorOpening != sectorOpening ||
      old.direction != direction ||
      old.operates != operates ||
      old.inSelectedSector != inSelectedSector ||
      old.opLabel != opLabel ||
      old.theta != theta;
}

enum _Anchor { center, left, right }
