import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/utils/per_unit.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

enum _Tab { bases, impedance, changeBase }

class PerUnitScreen extends StatefulWidget {
  const PerUnitScreen({super.key});

  @override
  State<PerUnitScreen> createState() => _PerUnitScreenState();
}

class _PerUnitScreenState extends State<PerUnitScreen> {
  _Tab _tab = _Tab.bases;

  final _sBase = TextEditingController(text: '100');
  final _vBase = TextEditingController(text: '138');

  final _zReal = TextEditingController(text: '50');
  final _zPu = TextEditingController(text: '0.2625');

  // Mudança de base
  final _zPuOld = TextEditingController(text: '0.2');
  final _sOld = TextEditingController(text: '100');
  final _vOld = TextEditingController(text: '138');
  final _sNew = TextEditingController(text: '200');
  final _vNew = TextEditingController(text: '138');

  List<_ResultEntry>? _results;

  @override
  void dispose() {
    for (final c in [
      _sBase, _vBase, _zReal, _zPu,
      _zPuOld, _sOld, _vOld, _sNew, _vNew,
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
    final results = <_ResultEntry>[];

    switch (_tab) {
      case _Tab.bases:
        final s = _parse(_sBase);
        final v = _parse(_vBase);
        if (s > 0 && v > 0) {
          results.add(_ResultEntry(
              'Z base', impedanceBase(sBaseMva: s, vBaseKv: v), 'Ω'));
          results.add(_ResultEntry(
              'I base', currentBase(sBaseMva: s, vBaseKv: v), 'A'));
        }
        break;
      case _Tab.impedance:
        final s = _parse(_sBase);
        final v = _parse(_vBase);
        if (s > 0 && v > 0) {
          results.add(_ResultEntry(
              'Z base', impedanceBase(sBaseMva: s, vBaseKv: v), 'Ω'));
          results.add(_ResultEntry(
            'Z real → pu',
            zPuFromReal(zRealOhm: _parse(_zReal), sBaseMva: s, vBaseKv: v),
            'pu',
          ));
          results.add(_ResultEntry(
            'Z pu → real',
            zRealFromPu(zPu: _parse(_zPu), sBaseMva: s, vBaseKv: v),
            'Ω',
          ));
        }
        break;
      case _Tab.changeBase:
        final sOld = _parse(_sOld);
        final vOld = _parse(_vOld);
        final sNew = _parse(_sNew);
        final vNew = _parse(_vNew);
        if (sOld > 0 && vOld > 0 && sNew > 0 && vNew > 0) {
          results.add(_ResultEntry(
            'Z pu (nova base)',
            changeImpedanceBase(
              zPuOld: _parse(_zPuOld),
              sBaseOldMva: sOld,
              vBaseOldKv: vOld,
              sBaseNewMva: sNew,
              vBaseNewKv: vNew,
            ),
            'pu',
          ));
        }
        break;
    }

    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Valor por Unidade (PU)'),
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
                    _buildTabSelector(),
                    const SizedBox(height: 20),
                    _buildBaseInputs(),
                    if (_tab != _Tab.changeBase) ...[
                      const SizedBox(height: 16),
                      if (_tab == _Tab.impedance) _buildImpedanceInputs(),
                    ],
                    if (_tab == _Tab.changeBase) ...[
                      const SizedBox(height: 16),
                      _buildChangeBaseInputs(),
                    ],
                    const SizedBox(height: 20),
                    Semantics(
                      button: true,
                      label: 'Calcular',
                      child: ElevatedButton.icon(
                        onPressed: _calculate,
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('CALCULAR'),
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

  Widget _buildTabSelector() {
    return Semantics(
      label: 'Selecionar tipo de conversão',
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
            _tabItem('Bases', _Tab.bases),
            _tabItem('Impedância', _Tab.impedance),
            _tabItem('Mudar base', _Tab.changeBase),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String title, _Tab tab) {
    final selected = _tab == tab;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _tab = tab;
              _results = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
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
            child: Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBaseInputs() {
    return _InputCard(
      title: 'Grandezas de base',
      children: [
        _NumberField(
          controller: _sBase,
          label: 'Potência de base S (MVA)',
          semantic: 'Potência de base em MVA',
        ),
        const SizedBox(height: 12),
        _NumberField(
          controller: _vBase,
          label: 'Tensão de base V (kV)',
          semantic: 'Tensão de base em kV',
        ),
      ],
    );
  }

  Widget _buildImpedanceInputs() {
    return _InputCard(
      title: 'Conversão de impedância',
      children: [
        _NumberField(
          controller: _zReal,
          label: 'Z real (Ω)',
          semantic: 'Impedância real em ohms',
        ),
        const SizedBox(height: 12),
        _NumberField(
          controller: _zPu,
          label: 'Z (pu)',
          semantic: 'Impedância em por unidade',
        ),
      ],
    );
  }

  Widget _buildChangeBaseInputs() {
    return _InputCard(
      title: 'Mudança de base',
      children: [
        _NumberField(
          controller: _zPuOld,
          label: 'Z pu (base antiga)',
          semantic: 'Impedância em pu na base antiga',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: _sOld,
                label: 'S antiga (MVA)',
                semantic: 'Potência de base antiga',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberField(
                controller: _vOld,
                label: 'V antiga (kV)',
                semantic: 'Tensão de base antiga',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: _sNew,
                label: 'S nova (MVA)',
                semantic: 'Potência de base nova',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberField(
                controller: _vNew,
                label: 'V nova (kV)',
                semantic: 'Tensão de base nova',
              ),
            ),
          ],
        ),
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
          const SizedBox(height: 12),
          ...children,
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
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

class _ResultEntry {
  final String label;
  final double value;
  final String unit;

  _ResultEntry(this.label, this.value, this.unit);

  String get valueText {
    if (value.abs() >= 1000 || (value.abs() < 0.001 && value != 0)) {
      return value.toStringAsExponential(4);
    }
    return value.toStringAsFixed(4);
  }

  String get clipboardText => '$label: $valueText $unit';
}

class _ResultsPanel extends StatelessWidget {
  final List<_ResultEntry> results;

  const _ResultsPanel({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Verifique os valores de entrada (devem ser maiores que zero).',
          style: TextStyle(color: AppColors.warning, fontSize: 13),
        ),
      );
    }
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
                label: 'Copiar todos os resultados',
                child: IconButton(
                  icon: const Icon(Icons.copy_all_outlined,
                      color: AppColors.primary, size: 20),
                  tooltip: 'Copiar tudo',
                  onPressed: () {
                    final text =
                        results.map((r) => r.clipboardText).join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    HapticFeedback.lightImpact();
                    SparkSnack.success(context, 'Resultados copiados');
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
        label: '${r.label}: ${r.valueText} ${r.unit}',
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
                '${r.valueText} ${r.unit}',
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
              label: 'Copiar ${r.label}',
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
