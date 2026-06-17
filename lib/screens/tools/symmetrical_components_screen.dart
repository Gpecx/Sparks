import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/utils/complex_number.dart';
import 'package:spark_app/utils/symmetrical_components.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

enum _Mode { decompose, synthesize }

class SymmetricalComponentsScreen extends StatefulWidget {
  const SymmetricalComponentsScreen({super.key});

  @override
  State<SymmetricalComponentsScreen> createState() =>
      _SymmetricalComponentsScreenState();
}

class _SymmetricalComponentsScreenState
    extends State<SymmetricalComponentsScreen> {
  _Mode _mode = _Mode.decompose;

  // Entradas no modo decompor (fasores de fase ABC)
  final _aMag = TextEditingController(text: '1');
  final _aAng = TextEditingController(text: '0');
  final _bMag = TextEditingController(text: '1');
  final _bAng = TextEditingController(text: '-120');
  final _cMag = TextEditingController(text: '1');
  final _cAng = TextEditingController(text: '120');

  // Entradas no modo sintetizar (componentes de sequência 0/1/2)
  final _z0Mag = TextEditingController(text: '0');
  final _z0Ang = TextEditingController(text: '0');
  final _z1Mag = TextEditingController(text: '1');
  final _z1Ang = TextEditingController(text: '0');
  final _z2Mag = TextEditingController(text: '0');
  final _z2Ang = TextEditingController(text: '0');

  List<_ResultEntry>? _results;

  @override
  void dispose() {
    for (final c in [
      _aMag, _aAng, _bMag, _bAng, _cMag, _cAng,
      _z0Mag, _z0Ang, _z1Mag, _z1Ang, _z2Mag, _z2Ang,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;

  void _calculate() {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    if (_mode == _Mode.decompose) {
      final phase = PhaseComponents(
        a: Complex.polarDegrees(_parse(_aMag), _parse(_aAng)),
        b: Complex.polarDegrees(_parse(_bMag), _parse(_bAng)),
        c: Complex.polarDegrees(_parse(_cMag), _parse(_cAng)),
      );
      final seq = decompose(phase);
      setState(() {
        _results = [
          _ResultEntry('V₀ (sequência zero)', seq.zero),
          _ResultEntry('V₁ (sequência positiva)', seq.positive),
          _ResultEntry('V₂ (sequência negativa)', seq.negative),
        ];
      });
    } else {
      final seq = SequenceComponents(
        zero: Complex.polarDegrees(_parse(_z0Mag), _parse(_z0Ang)),
        positive: Complex.polarDegrees(_parse(_z1Mag), _parse(_z1Ang)),
        negative: Complex.polarDegrees(_parse(_z2Mag), _parse(_z2Ang)),
      );
      final phase = synthesize(seq);
      setState(() {
        _results = [
          _ResultEntry('Va (fase A)', phase.a),
          _ResultEntry('Vb (fase B)', phase.b),
          _ResultEntry('Vc (fase C)', phase.c),
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(AppLocalizations.of(context)!.symmetricalTitle),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 20),
                    if (_mode == _Mode.decompose)
                      _buildDecomposeInputs()
                    else
                      _buildSynthesizeInputs(),
                    const SizedBox(height: 20),
                    Semantics(
                      button: true,
                      label: AppLocalizations.of(context)!.perUnitCalculateBtn,
                      child: ElevatedButton.icon(
                        onPressed: _calculate,
                        icon: const Icon(Icons.calculate_outlined),
                        label: Text(AppLocalizations.of(context)!.perUnitCalculateUpper),
                      ),
                    ),
                    if (_results != null) ...[
                      const SizedBox(height: 24),
                      _ResultsPanel(results: _results!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Semantics(
      label: AppLocalizations.of(context)!.tlSelectCalcMode,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.cardBorder.withValues(alpha: 0.4),
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _modeTab('Decompor', AppLocalizations.of(context)!.symmetricalTabPhaseToSeq, _Mode.decompose),
            _modeTab('Sintetizar', AppLocalizations.of(context)!.symmetricalTabSeqToPhase, _Mode.synthesize),
          ],
        ),
      ),
    );
  }

  Widget _modeTab(String title, String subtitle, _Mode mode) {
    final selected = _mode == mode;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$title, $subtitle',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _mode = mode;
              _results = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.8)
                        : AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecomposeInputs() {
    return _InputCard(
      title: AppLocalizations.of(context)!.tlPhasePhasors,
      children: [
        _PhasorRow(label: 'Va', magCtrl: _aMag, angCtrl: _aAng),
        _PhasorRow(label: 'Vb', magCtrl: _bMag, angCtrl: _bAng),
        _PhasorRow(label: 'Vc', magCtrl: _cMag, angCtrl: _cAng),
      ],
    );
  }

  Widget _buildSynthesizeInputs() {
    return _InputCard(
      title: AppLocalizations.of(context)!.tlSequenceComponents,
      children: [
        _PhasorRow(label: 'V₀', magCtrl: _z0Mag, angCtrl: _z0Ang),
        _PhasorRow(label: 'V₁', magCtrl: _z1Mag, angCtrl: _z1Ang),
        _PhasorRow(label: 'V₂', magCtrl: _z2Mag, angCtrl: _z2Ang),
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InputCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Módulo e ângulo (graus)',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _PhasorRow extends StatelessWidget {
  final String label;
  final TextEditingController magCtrl;
  final TextEditingController angCtrl;

  const _PhasorRow({
    required this.label,
    required this.magCtrl,
    required this.angCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: _NumberField(
              controller: magCtrl,
              label: AppLocalizations.of(context)!.tlMagnitude,
              semantic: 'Módulo de $label',
            ),
          ),
          const SizedBox(width: 10),
          const Text('∠', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: _NumberField(
              controller: angCtrl,
              label: AppLocalizations.of(context)!.tlAngleDeg,
              semantic: 'Ângulo de $label em graus',
            ),
          ),
        ],
      ),
    );
  }
}

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
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _ResultEntry {
  final String label;
  final Complex value;

  _ResultEntry(this.label, this.value);

  String get magnitudeText => value.magnitude.toStringAsFixed(4);
  String get angleText => value.angleDegrees.toStringAsFixed(2);
  String get clipboardText => '$label: $magnitudeText∠$angleText°';
}

class _ResultsPanel extends StatelessWidget {
  final List<_ResultEntry> results;

  const _ResultsPanel({required this.results});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Resultados',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: AppLocalizations.of(context)!.tlCopyAll,
                child: IconButton(
                  icon: const Icon(Icons.copy_all_outlined,
                      color: AppColors.primary, size: 20),
                  tooltip: 'Copiar tudo',
                  onPressed: () {
                    final text =
                        results.map((r) => r.clipboardText).join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    HapticFeedback.lightImpact();
                    SparkSnack.success(context, AppLocalizations.of(context)!.tlResultsCopied);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...results.map((r) => _resultRow(context, r)),
        ],
      ),
    );
  }

  Widget _resultRow(BuildContext context, _ResultEntry r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        label: AppLocalizations.of(context)!.a11ySymResult(r.label, r.magnitudeText, r.angleText),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                r.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${r.magnitudeText}∠${r.angleText}°',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: AppLocalizations.of(context)!.a11yCopy(r.label),
              child: IconButton(
                icon: const Icon(Icons.copy_outlined,
                    color: AppColors.textMuted, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Copiar',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: r.clipboardText));
                  HapticFeedback.selectionClick();
                  SparkSnack.success(context, '${r.label} copiado');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
