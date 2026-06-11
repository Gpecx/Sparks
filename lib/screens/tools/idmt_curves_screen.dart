import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/idmt_curves.dart';
import 'package:spark_app/utils/coordinogram.dart';
import 'package:spark_app/screens/tools/widgets/idmt_curve_picker.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class IdmtCurvesScreen extends StatefulWidget {
  const IdmtCurvesScreen({super.key});

  @override
  State<IdmtCurvesScreen> createState() => _IdmtCurvesScreenState();
}

class _IdmtCurvesScreenState extends State<IdmtCurvesScreen> {
  int _mode = 0; // 0 = cálculo (1 curva), 1 = coordenograma (comparar)

  // ── Modo cálculo ────────────────────────────────────────────────
  IdmtCurve _curve = idmtCurves.first;
  final _iPickup = TextEditingController(text: '1');
  final _dial = TextEditingController(text: '1');
  final _iTest = TextEditingController(text: '5');

  // ── Modo coordenograma ──────────────────────────────────────────
  final List<_RelayInput> _relays = [
    _RelayInput(curve: idmtCurves.first, pickup: '100', td: '0.1'),
    _RelayInput(curve: idmtCurves.first, pickup: '100', td: '0.5'),
  ];
  final _faultCurrent = TextEditingController(text: '1000');
  final _cti = TextEditingController(text: '0.3');

  @override
  void initState() {
    super.initState();
    for (final c in [_iPickup, _dial, _iTest]) {
      c.addListener(() => setState(() {}));
    }
    for (final c in [_faultCurrent, _cti]) {
      c.addListener(() => setState(() {}));
    }
    for (final r in _relays) {
      r.pickupCtrl.addListener(() => setState(() {}));
      r.tdCtrl.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_iPickup, _dial, _iTest, _faultCurrent, _cti]) {
      c.dispose();
    }
    for (final r in _relays) {
      r.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));

  // ── cálculo helpers ─────────────────────────────────────────────
  double get _td => _parse(_dial) ?? 0;

  String? get _validationError {
    final ip = _parse(_iPickup);
    final it = _parse(_iTest);
    final td = _parse(_dial);
    if (ip == null || it == null || td == null) {
      return 'Preencha pickup, dial e corrente de teste.';
    }
    if (ip <= 0) return 'I pick-up deve ser maior que zero.';
    if (td <= 0) return 'Dial de tempo deve ser maior que zero.';
    if (it <= ip) return 'I teste deve ser maior que o I pick-up.';
    return null;
  }

  double? get _multiple {
    final ip = _parse(_iPickup);
    final it = _parse(_iTest);
    if (ip == null || it == null || ip <= 0) return null;
    return it / ip;
  }

  double? get _tripTime {
    if (_validationError != null) return null;
    final t = _curve.timeForMultiple(_multiple!, _td);
    if (t.isNaN || t.isInfinite || t < 0) return null;
    return t;
  }

  void _pickCurve() async {
    final selected = await showIdmtCurvePicker(context, selectedId: _curve.id);
    if (selected != null) setState(() => _curve = selected);
  }

  void _pickRelayCurve(int i) async {
    final selected =
        await showIdmtCurvePicker(context, selectedId: _relays[i].curve.id);
    if (selected != null) setState(() => _relays[i].curve = selected);
  }

  void _addRelay() {
    setState(() {
      final r = _RelayInput(curve: idmtCurves.first, pickup: '100', td: '0.3');
      r.pickupCtrl.addListener(() => setState(() {}));
      r.tdCtrl.addListener(() => setState(() {}));
      _relays.add(r);
    });
  }

  void _removeRelay(int i) {
    setState(() {
      _relays[i].dispose();
      _relays.removeAt(i);
    });
  }

  // Lista de relés válidos (parse ok) para plotagem/CTI.
  List<CoordRelay> get _coordRelays {
    final out = <CoordRelay>[];
    for (var i = 0; i < _relays.length; i++) {
      final p = double.tryParse(_relays[i].pickupCtrl.text.replaceAll(',', '.'));
      final t = double.tryParse(_relays[i].tdCtrl.text.replaceAll(',', '.'));
      if (p != null && p > 0 && t != null && t > 0) {
        out.add(CoordRelay(
          label: 'R${i + 1}',
          curve: _relays[i].curve,
          pickupA: p,
          td: t,
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Curvas de Sobrecorrente (51)'),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _modeSelector(),
                    const SizedBox(height: 16),
                    if (_mode == 0) ..._buildCalcMode() else ..._buildCoordMode(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _mode = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == _mode
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: i == _mode
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    i == 0 ? 'Cálculo (1 curva)' : 'Comparar curvas',
                    style: TextStyle(
                      color: i == _mode
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Modo cálculo (fluxo original) ───────────────────────────────
  List<Widget> _buildCalcMode() {
    final error = _validationError;
    final time = _tripTime;
    return [
      _buildCurveSelector(),
      const SizedBox(height: 16),
      _buildCoefficients(),
      const SizedBox(height: 16),
      _buildInputs(),
      const SizedBox(height: 20),
      _buildResult(error, time),
      const SizedBox(height: 20),
      _buildChartCard(),
    ];
  }

  Widget _buildCurveSelector() {
    return Semantics(
      button: true,
      label: 'Curva selecionada: ${_curve.name}. Toque para trocar.',
      child: GestureDetector(
        onTap: _pickCurve,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.show_chart, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Curva selecionada',
                      style: TextStyle(
                        color: AppColors.textMuted.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _curve.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _curve.family,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more, color: AppColors.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoefficients() {
    final items = <MapEntry<String, double>>[
      MapEntry('A', _curve.a),
      MapEntry('P', _curve.p),
      MapEntry('Q', _curve.q),
      MapEntry('B', _curve.b),
      MapEntry('K1', _curve.k1),
      MapEntry('K2', _curve.k2),
    ];
    String fmt(double v) {
      final s = v.toStringAsFixed(4);
      return s.replaceFirst(RegExp(r'\.?0+$'), '');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coeficientes  ·  t = (A·Td + K1)/(M^P − Q) + B·Td + K2',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                items.map((e) => _coefChip(e.key, fmt(e.value))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _coefChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label = ',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: _iPickup,
                  label: 'I pick-up (A)',
                  semantic: 'Corrente de pick-up em ampères',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  controller: _dial,
                  label: 'Dial de tempo (Td)',
                  semantic: 'Dial de tempo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NumberField(
            controller: _iTest,
            label: 'I teste (A)',
            semantic: 'Corrente de teste em ampères',
          ),
        ],
      ),
    );
  }

  Widget _buildResult(String? error, double? time) {
    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final m = _multiple!;
    final secondsText = '${time!.toStringAsFixed(time < 1 ? 4 : 3)} s';
    final formatted = formatTripTime(time);
    final clip = '${_curve.name}\n'
        'M = ${m.toStringAsFixed(3)} · Td = ${_td.toStringAsFixed(3)}\n'
        'Tempo de atuação: $secondsText ($formatted)';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tempo de atuação',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Copiar resultado',
                child: IconButton(
                  icon: const Icon(Icons.copy_outlined,
                      color: AppColors.primary, size: 20),
                  tooltip: 'Copiar',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: clip));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Resultado copiado')),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Tempo de atuação $secondsText, equivalente a $formatted',
            child: Text(
              secondsText,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
          ),
          Text(
            '$formatted  (hh:mm:ss.cc)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'M = I_teste / I_pickup = ${m.toStringAsFixed(3)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Curva tempo × múltiplo (log-log)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.25,
            child: Semantics(
              label: 'Gráfico log-log da curva ${_curve.name}',
              child: CustomPaint(
                painter: _TccPainter(
                  curve: _curve,
                  td: _td > 0 ? _td : 1,
                  testMultiple: _validationError == null ? _multiple : null,
                  testTime: _tripTime,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Modo coordenograma ──────────────────────────────────────────
  List<Widget> _buildCoordMode() {
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.stacked_line_chart,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sobreponha as curvas (em ampères primários) e veja o intervalo '
                'de coordenação (CTI) na corrente de falta. Eixo X = corrente, '
                'eixo Y = tempo.',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < _relays.length; i++) ...[
        _relayCard(i),
        const SizedBox(height: 10),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _relays.length < 5 ? _addRelay : null,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text('Adicionar relé'),
        ),
      ),
      const SizedBox(height: 6),
      _coordFaultCard(),
      const SizedBox(height: 16),
      _coordChartCard(),
      const SizedBox(height: 16),
      _ctiResultCard(),
    ];
  }

  Widget _relayCard(int i) {
    final r = _relays[i];
    final color = _relayColors[i % _relayColors.length];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 14,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Text('Relé R${i + 1}',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Spacer(),
              if (_relays.length > 2)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.textMuted, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remover',
                  onPressed: () => _removeRelay(i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickRelayCurve(i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.curve.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13)),
                  ),
                  const Icon(Icons.unfold_more,
                      color: AppColors.primary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                    controller: r.pickupCtrl,
                    label: 'I> pickup (A)',
                    semantic: 'Pickup do relé ${i + 1}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                    controller: r.tdCtrl,
                    label: 'Dial (Td)',
                    semantic: 'Dial do relé ${i + 1}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coordFaultCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _NumberField(
                controller: _faultCurrent,
                label: 'Corrente de falta (A)',
                semantic: 'Corrente de falta em ampères'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _NumberField(
                controller: _cti,
                label: 'CTI requerido (s)',
                semantic: 'Intervalo de coordenação requerido'),
          ),
        ],
      ),
    );
  }

  Widget _coordChartCard() {
    final relays = _coordRelays;
    final fault = _parse(_faultCurrent);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Coordenograma tempo × corrente (log-log)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.1,
            child: CustomPaint(
              painter: _CoordPainter(
                relays: relays,
                colors: _relayColors,
                faultCurrent: (fault != null && fault > 0) ? fault : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (var i = 0; i < relays.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 11, height: 11,
                        decoration: BoxDecoration(
                            color: _relayColors[i % _relayColors.length],
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 5),
                    Text('${relays[i].label} · ${relays[i].curve.name}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ctiResultCard() {
    final relays = _coordRelays;
    final fault = _parse(_faultCurrent);
    final cti = _parse(_cti) ?? 0.3;
    if (relays.length < 2 || fault == null || fault <= 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Informe ≥ 2 relés válidos e a corrente de falta para checar o CTI.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    // Ordena por tempo no ponto de falta: o mais rápido é o "principal".
    final timed = <MapEntry<CoordRelay, double>>[];
    for (final r in relays) {
      final t = r.timeAtCurrent(fault);
      if (t != null) timed.add(MapEntry(r, t));
    }
    timed.sort((a, b) => a.value.compareTo(b.value));

    final rows = <Widget>[];
    bool anyBad = false;
    for (var i = 0; i < timed.length - 1; i++) {
      final main = timed[i].key;
      final backup = timed[i + 1].key;
      final c = checkCti(
          main: main, backup: backup, faultCurrentA: fault, requiredCti: cti);
      if (!c.ok) anyBad = true;
      rows.add(_ctiRow(main.label, backup.label, c));
    }
    if (timed.length < 2) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Apenas ${timed.length} relé sensibiliza em ${fmt0(fault)} A. '
          'Aumente a corrente ou reduza os pickups.',
          style: const TextStyle(color: AppColors.warning, fontSize: 12),
        ),
      );
    }

    final color = anyBad ? AppColors.warning : AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(anyBad ? Icons.error_outline : Icons.check_circle_outline,
                  color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                anyBad
                    ? 'Falha de coordenação em ${fmt0(fault)} A'
                    : 'Coordenação OK em ${fmt0(fault)} A',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _ctiRow(String mainLabel, String backupLabel, CtiCheck c) {
    final color = c.ok ? AppColors.primary : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(c.ok ? Icons.check : Icons.priority_high, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$backupLabel após $mainLabel: '
              'Δt = ${c.margin!.toStringAsFixed(3)} s '
              '(req. ${c.requiredCti.toStringAsFixed(2)} s)',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String fmt0(double v) => v.toStringAsFixed(0);
}

// Entrada editável de um relé do coordenograma.
class _RelayInput {
  IdmtCurve curve;
  final TextEditingController pickupCtrl;
  final TextEditingController tdCtrl;
  _RelayInput(
      {required this.curve, required String pickup, required String td})
      : pickupCtrl = TextEditingController(text: pickup),
        tdCtrl = TextEditingController(text: td);
  void dispose() {
    pickupCtrl.dispose();
    tdCtrl.dispose();
  }
}

const _relayColors = <Color>[
  Color(0xFF00C402),
  Color(0xFF38BDF8),
  Color(0xFFF97316),
  Color(0xFFA855F7),
  Color(0xFFEAB308),
];

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String semantic;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.semantic,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semantic,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

// ── Pintor do gráfico log-log tempo × múltiplo (modo cálculo) ────
class _TccPainter extends CustomPainter {
  final IdmtCurve curve;
  final double td;
  final double? testMultiple;
  final double? testTime;

  static const double xMin = 1;
  static const double xMax = 20;
  static const double yMin = 0.01;
  static const double yMax = 1000;

  _TccPainter({
    required this.curve,
    required this.td,
    this.testMultiple,
    this.testTime,
  });

  static const double _padLeft = 44;
  static const double _padBottom = 24;
  static const double _padTop = 8;
  static const double _padRight = 10;

  double _lx(double m) =>
      (math.log(m) - math.log(xMin)) / (math.log(xMax) - math.log(xMin));
  double _ly(double t) =>
      (math.log(t) - math.log(yMin)) / (math.log(yMax) - math.log(yMin));

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );

    Offset toPx(double m, double t) {
      final fx = _lx(m).clamp(0.0, 1.0);
      final fy = _ly(t).clamp(0.0, 1.0);
      return Offset(
        plot.left + fx * plot.width,
        plot.bottom - fy * plot.height,
      );
    }

    final bg = Paint()..color = AppColors.background.withValues(alpha: 0.4);
    canvas.drawRect(plot, bg);

    final grid = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final textStyle = TextStyle(
      color: AppColors.textMuted.withValues(alpha: 0.9),
      fontSize: 9,
    );

    for (final decade in [0.01, 0.1, 1.0, 10.0, 100.0, 1000.0]) {
      final y = plot.bottom - _ly(decade).clamp(0.0, 1.0) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(canvas, _fmtAxis(decade), Offset(plot.left - 4, y), textStyle,
          alignRight: true, alignMiddle: true);
    }

    for (final mult in [1.0, 2.0, 3.0, 5.0, 10.0, 20.0]) {
      final x = plot.left + _lx(mult).clamp(0.0, 1.0) * plot.width;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      _label(canvas, _fmtAxis(mult), Offset(x, plot.bottom + 4), textStyle,
          alignCenter: true);
    }

    final border = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(plot, border);

    final curvePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool started = false;
    const samples = 240;
    for (int i = 0; i <= samples; i++) {
      final f = i / samples;
      final m =
          math.exp(math.log(xMin) + f * (math.log(xMax) - math.log(xMin)));
      if (m <= 1.0001) continue;
      final t = curve.timeForMultiple(m, td);
      if (t.isNaN || t.isInfinite || t <= 0) {
        started = false;
        continue;
      }
      final fy = _ly(t);
      if (fy < 0 || fy > 1) {
        started = false;
        continue;
      }
      final pt = toPx(m, t);
      if (!started) {
        path.moveTo(pt.dx, pt.dy);
        started = true;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.save();
    canvas.clipRect(plot);
    canvas.drawPath(path, curvePaint);

    if (testMultiple != null &&
        testTime != null &&
        testTime! > 0 &&
        _ly(testTime!) >= 0 &&
        _ly(testTime!) <= 1 &&
        _lx(testMultiple!) >= 0 &&
        _lx(testMultiple!) <= 1) {
      final pt = toPx(testMultiple!, testTime!);
      final cross = Paint()
        ..color = AppColors.gold
        ..strokeWidth = 1;
      canvas.drawLine(Offset(plot.left, pt.dy), Offset(plot.right, pt.dy),
          cross..color = AppColors.gold.withValues(alpha: 0.4));
      canvas.drawLine(Offset(pt.dx, plot.top), Offset(pt.dx, plot.bottom),
          cross..color = AppColors.gold.withValues(alpha: 0.4));
      canvas.drawCircle(pt, 5, Paint()..color = AppColors.gold);
      canvas.drawCircle(
          pt,
          5,
          Paint()
            ..color = AppColors.background
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    canvas.restore();
  }

  String _fmtAxis(double v) {
    if (v >= 1) return v.toStringAsFixed(0);
    if (v == 0.1) return '0,1';
    if (v == 0.01) return '0,01';
    return v.toString();
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style,
      {bool alignRight = false,
      bool alignCenter = false,
      bool alignMiddle = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = at.dx;
    double dy = at.dy;
    if (alignRight) dx -= tp.width;
    if (alignCenter) dx -= tp.width / 2;
    if (alignMiddle) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_TccPainter old) =>
      old.curve.id != curve.id ||
      old.td != td ||
      old.testMultiple != testMultiple ||
      old.testTime != testTime;
}

// ── Pintor do coordenograma tempo × corrente (modo comparar) ─────
class _CoordPainter extends CustomPainter {
  final List<CoordRelay> relays;
  final List<Color> colors;
  final double? faultCurrent;

  // Eixo de corrente fixo (A) e tempo (s), em décadas log.
  static const double xMin = 10;
  static const double xMax = 100000;
  static const double yMin = 0.01;
  static const double yMax = 1000;

  _CoordPainter({
    required this.relays,
    required this.colors,
    this.faultCurrent,
  });

  static const double _padLeft = 44;
  static const double _padBottom = 24;
  static const double _padTop = 8;
  static const double _padRight = 10;

  double _lx(double a) =>
      (math.log(a) - math.log(xMin)) / (math.log(xMax) - math.log(xMin));
  double _ly(double t) =>
      (math.log(t) - math.log(yMin)) / (math.log(yMax) - math.log(yMin));

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
        _padLeft, _padTop, size.width - _padRight, size.height - _padBottom);

    Offset toPx(double a, double t) => Offset(
          plot.left + _lx(a).clamp(0.0, 1.0) * plot.width,
          plot.bottom - _ly(t).clamp(0.0, 1.0) * plot.height,
        );

    canvas.drawRect(
        plot, Paint()..color = AppColors.background.withValues(alpha: 0.4));

    final grid = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final textStyle = TextStyle(
        color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 9);

    for (final decade in [0.01, 0.1, 1.0, 10.0, 100.0, 1000.0]) {
      final y = plot.bottom - _ly(decade).clamp(0.0, 1.0) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(canvas, _fmtTime(decade), Offset(plot.left - 4, y), textStyle,
          alignRight: true, alignMiddle: true);
    }
    for (final amp in [10.0, 100.0, 1000.0, 10000.0, 100000.0]) {
      final x = plot.left + _lx(amp).clamp(0.0, 1.0) * plot.width;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      _label(canvas, _fmtAmp(amp), Offset(x, plot.bottom + 4), textStyle,
          alignCenter: true);
    }

    canvas.drawRect(
        plot,
        Paint()
          ..color = AppColors.cardBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    canvas.save();
    canvas.clipRect(plot);

    // Linha vertical da corrente de falta
    if (faultCurrent != null &&
        _lx(faultCurrent!) >= 0 &&
        _lx(faultCurrent!) <= 1) {
      final x = plot.left + _lx(faultCurrent!) * plot.width;
      canvas.drawLine(
          Offset(x, plot.top),
          Offset(x, plot.bottom),
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.6)
            ..strokeWidth = 1.5);
    }

    // Curvas dos relés (tempo × corrente)
    for (var i = 0; i < relays.length; i++) {
      final r = relays[i];
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      bool started = false;
      const samples = 260;
      for (int s = 0; s <= samples; s++) {
        final f = s / samples;
        final a =
            math.exp(math.log(xMin) + f * (math.log(xMax) - math.log(xMin)));
        final t = r.timeAtCurrent(a);
        if (t == null || t <= 0) {
          started = false;
          continue;
        }
        final fy = _ly(t);
        if (fy < 0 || fy > 1) {
          started = false;
          continue;
        }
        final pt = toPx(a, t);
        if (!started) {
          path.moveTo(pt.dx, pt.dy);
          started = true;
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, paint);

      // Ponto na corrente de falta
      if (faultCurrent != null) {
        final t = r.timeAtCurrent(faultCurrent!);
        if (t != null && _ly(t) >= 0 && _ly(t) <= 1) {
          final pt = toPx(faultCurrent!, t);
          canvas.drawCircle(pt, 4, Paint()..color = colors[i % colors.length]);
        }
      }
    }
    canvas.restore();
  }

  String _fmtTime(double v) {
    if (v >= 1) return v.toStringAsFixed(0);
    if (v == 0.1) return '0,1';
    if (v == 0.01) return '0,01';
    return v.toString();
  }

  String _fmtAmp(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style,
      {bool alignRight = false,
      bool alignCenter = false,
      bool alignMiddle = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = at.dx;
    double dy = at.dy;
    if (alignRight) dx -= tp.width;
    if (alignCenter) dx -= tp.width / 2;
    if (alignMiddle) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_CoordPainter old) => true;
}
