import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/equipment_current.dart';
import 'package:spark_app/utils/inrush_bank.dart';
import 'package:spark_app/utils/inrush_estimate.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class EquipmentCurrentScreen extends StatefulWidget {
  const EquipmentCurrentScreen({super.key});

  @override
  State<EquipmentCurrentScreen> createState() => _EquipmentCurrentScreenState();
}

// Uma linha editável da tabela de trafos do banco.
class _BankRow {
  final TextEditingController kva;
  final TextEditingController factor;
  _BankRow({String kva = '1000', String factor = '10'})
      : kva = TextEditingController(text: kva),
        factor = TextEditingController(text: factor);
  void dispose() {
    kva.dispose();
    factor.dispose();
  }
}

class _EquipmentCurrentScreenState extends State<EquipmentCurrentScreen> {
  int _mode = 0; // 0 = transformador, 1 = motor, 2 = inrush banco, 3 = inrush real

  // Inrush real (estima o pico a partir do trafo)
  final _irPower = TextEditingController(text: '1000');
  final _irVolt = TextEditingController(text: '13.8');
  final _irZcc = TextEditingController(text: '6');
  final _irResidual = TextEditingController(text: '0.6');
  final _irPickup50 = TextEditingController(text: '');

  // Transformador
  final _power = TextEditingController(text: '1000');
  final _vPrim = TextEditingController(text: '13.8');
  final _vSec = TextEditingController(text: '0.38');
  final _inrush = TextEditingController(text: '10');

  // Motor
  final _mPower = TextEditingController(text: '75');
  final _mVolt = TextEditingController(text: '380');
  final _mPf = TextEditingController(text: '0.85');
  final _mEff = TextEditingController(text: '0.93');
  final _startFactor = TextEditingController(text: '6');

  // Inrush de banco
  final _bankVolt = TextEditingController(text: '13.8');
  final _coincidence = TextEditingController(text: '1.0');
  final _pickup50 = TextEditingController(text: '');
  final List<_BankRow> _bankRows = [
    _BankRow(kva: '1000', factor: '10'),
    _BankRow(kva: '500', factor: '12'),
  ];

  List<ToolResult>? _results;
  String? _warning;
  String? _verdict;
  bool _verdictBad = false;

  @override
  void dispose() {
    for (final c in [
      _power, _vPrim, _vSec, _inrush,
      _mPower, _mVolt, _mPf, _mEff, _startFactor,
      _bankVolt, _coincidence, _pickup50,
      _irPower, _irVolt, _irZcc, _irResidual, _irPickup50,
    ]) {
      c.dispose();
    }
    for (final r in _bankRows) {
      r.dispose();
    }
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _addRow() {
    setState(() => _bankRows.add(_BankRow()));
  }

  void _removeRow(int i) {
    setState(() {
      _bankRows[i].dispose();
      _bankRows.removeAt(i);
    });
  }

  void _calculate() {
    if (_mode == 0) {
      _calcTransformer();
    } else if (_mode == 1) {
      _calcMotor();
    } else if (_mode == 2) {
      _calcBank();
    } else {
      _calcInrushReal();
    }
  }

  void _calcTransformer() {
    final s = _p(_power);
    final vp = _p(_vPrim);
    if (s == null || vp == null || s <= 0 || vp <= 0) {
      setState(() {
        _warning = 'Informe potência (kVA) e tensão primária (kV) > 0.';
        _results = null;
        _verdict = null;
      });
      return;
    }
    final inPrim = transformerRatedCurrent(powerKva: s, voltageKv: vp);
    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.equipmentPriIn, '${fmtNumber(inPrim, decimals: 2)} A'),
    ];
    final vs = _p(_vSec);
    if (vs != null && vs > 0) {
      final inSec = transformerRatedCurrent(powerKva: s, voltageKv: vs);
      results.add(ToolResult(AppLocalizations.of(context)!.equipmentSecIn, '${fmtNumber(inSec, decimals: 2)} A'));
    }
    final k = _p(_inrush);
    if (k != null && k > 0) {
      results.add(ToolResult(
          'Inrush estimado (${fmtNumber(k, decimals: 0)}×)',
          '${fmtNumber(inPrim * k, decimals: 1)} A'));
    }
    setState(() {
      _warning = null;
      _verdict = null;
      _results = results;
    });
  }

  void _calcMotor() {
    final p = _p(_mPower);
    final v = _p(_mVolt);
    final pf = _p(_mPf);
    final eff = _p(_mEff);
    if (p == null || v == null || pf == null || eff == null ||
        p <= 0 || v <= 0 || pf <= 0 || eff <= 0) {
      setState(() {
        _warning = 'Preencha potência, tensão, FP e rendimento (> 0).';
        _results = null;
        _verdict = null;
      });
      return;
    }
    final inMotor = motorRatedCurrent(
        powerKw: p, voltageV: v, powerFactor: pf, efficiency: eff);
    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.equipmentNomI, '${fmtNumber(inMotor, decimals: 2)} A'),
    ];
    final k = _p(_startFactor);
    if (k != null && k > 0) {
      results.add(ToolResult(
          'Corrente de partida (${fmtNumber(k, decimals: 0)}×)',
          '${fmtNumber(inMotor * k, decimals: 1)} A'));
    }
    setState(() {
      _warning = null;
      _verdict = null;
      _results = results;
    });
  }

  void _calcBank() {
    final v = _p(_bankVolt);
    final cf = _p(_coincidence);
    if (v == null || v <= 0 || cf == null) {
      setState(() {
        _warning = 'Informe a tensão do barramento e o fator de coincidência.';
        _results = null;
        _verdict = null;
      });
      return;
    }
    final trafos = <TransformerInrush>[];
    for (final row in _bankRows) {
      final kva = _p(row.kva);
      final k = _p(row.factor);
      if (kva != null && kva > 0 && k != null && k > 0) {
        trafos.add(TransformerInrush(
            ratedKva: kva, voltageKv: v, inrushFactor: k));
      }
    }
    if (trafos.isEmpty) {
      setState(() {
        _warning = 'Adicione ao menos um trafo com kVA e fator de inrush > 0.';
        _results = null;
        _verdict = null;
      });
      return;
    }
    final pickup = _p(_pickup50);
    final r = bankInrush(
      transformers: trafos,
      coincidenceFactor: cf,
      instantaneousPickupA: pickup,
    );

    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.equipmentBankSum, '${fmtNumber(r.totalRatedCurrent, decimals: 1)} A'),
      ToolResult(AppLocalizations.of(context)!.equipmentBankPeaks, '${fmtNumber(r.sumOfPeaks, decimals: 0)} A'),
      ToolResult('Inrush coincidente (×${fmtNumber(r.coincidenceFactor, decimals: 2)})',
          '${fmtNumber(r.coincidentInrush, decimals: 0)} A'),
    ];
    String? verdict;
    bool bad = false;
    if (r.marginPercent != null) {
      if (r.exceedsPickup) {
        bad = true;
        verdict = 'Inrush coincidente ULTRAPASSA o ajuste 50 '
            '(${fmtNumber(pickup!, decimals: 0)} A) em '
            '${fmtNumber(-r.marginPercent!, decimals: 0)}%. '
            'Risco de trip na energização — energizar em sequência ou rever o 50.';
      } else {
        verdict = 'Inrush coincidente dentro do ajuste 50 '
            '(${fmtNumber(pickup!, decimals: 0)} A), '
            'margem de ${fmtNumber(r.marginPercent!, decimals: 0)}%.';
      }
    }

    setState(() {
      _warning = null;
      _results = results;
      _verdict = verdict;
      _verdictBad = bad;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Corrente Nominal',
      children: [
        ToolSegmented(
          labels: [AppLocalizations.of(context)!.equipmentTransformer, AppLocalizations.of(context)!.equipmentMotor, 'Inrush banco', 'Inrush real'],
          selected: _mode,
          onSelect: (i) => setState(() {
            _mode = i;
            _results = null;
            _warning = null;
            _verdict = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_mode == 0)
          _transformerCard()
        else if (_mode == 1)
          _motorCard()
        else if (_mode == 2)
          _bankCard()
        else
          _inrushRealCard(),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: _results ?? const [], warning: _warning),
        ],
        if (_verdict != null) ...[
          const SizedBox(height: 12),
          _verdictBox(_verdict!, _verdictBad),
        ],
      ],
    );
  }

  Widget _transformerCard() {
    return ToolCard(
      title: AppLocalizations.of(context)!.equipmentTransformer,
      subtitle: AppLocalizations.of(context)!.equipmentTransfIn,
      children: [
        ToolField(controller: _power, label: AppLocalizations.of(context)!.equipmentPower),
        const SizedBox(height: 12),
        ToolFieldRow(children: [
          ToolField(controller: _vPrim, label: AppLocalizations.of(context)!.equipmentPriV),
          ToolField(controller: _vSec, label: AppLocalizations.of(context)!.equipmentSecV),
        ]),
        const SizedBox(height: 12),
        ToolField(controller: _inrush, label: AppLocalizations.of(context)!.equipmentTransfFactor),
      ],
    );
  }

  Widget _motorCard() {
    return ToolCard(
      title: AppLocalizations.of(context)!.equipmentMotor,
      subtitle: AppLocalizations.of(context)!.equipmentMotorDesc,
      children: [
        ToolFieldRow(children: [
          ToolField(controller: _mPower, label: AppLocalizations.of(context)!.equipmentMotorPower),
          ToolField(controller: _mVolt, label: AppLocalizations.of(context)!.equipmentVLL),
        ]),
        const SizedBox(height: 12),
        ToolFieldRow(children: [
          ToolField(controller: _mPf, label: AppLocalizations.of(context)!.equipmentMotorPF),
          ToolField(controller: _mEff, label: AppLocalizations.of(context)!.equipmentMotorEff),
        ]),
        const SizedBox(height: 12),
        ToolField(controller: _startFactor, label: AppLocalizations.of(context)!.equipmentMotorFactor),
      ],
    );
  }

  // ── Inrush real (estima o pico a partir do trafo) ───────
  void _calcInrushReal() {
    final s = _p(_irPower);
    final v = _p(_irVolt);
    final z = _p(_irZcc);
    final br = _p(_irResidual) ?? 0.6;
    if (s == null || v == null || z == null || s <= 0 || v <= 0 || z <= 0) {
      setState(() {
        _warning = 'Preencha potência (kVA), tensão (kV) e Z% (> 0).';
        _results = null;
        _verdict = null;
      });
      return;
    }
    final est = estimateInrush(
      powerKva: s, voltageKv: v, zccPercent: z, residualFlux: br,
    );
    final results = <ToolResult>[
      ToolResult('In', '${fmtNumber(est.ratedCurrent, decimals: 1)} A'),
      ToolResult(AppLocalizations.of(context)!.equipmentPeakK, '${fmtNumber(est.peakFactor, decimals: 1)}× In'),
      ToolResult(AppLocalizations.of(context)!.equipmentPeak, '${fmtNumber(est.peakCurrent, decimals: 0)} A'),
      ToolResult(AppLocalizations.of(context)!.equipmentHarmonic, '${fmtNumber(est.secondHarmonicRatio, decimals: 0)} %'),
    ];

    String? verdict;
    bool bad = false;
    final pickup = _p(_irPickup50);
    if (pickup != null && pickup > 0) {
      if (est.peakCurrent > pickup) {
        bad = true;
        verdict = 'Pico de inrush (${fmtNumber(est.peakCurrent, decimals: 0)} A) '
            'ULTRAPASSA o ajuste 50 (${fmtNumber(pickup, decimals: 0)} A). '
            'Use bloqueio por 2º harmônico ou temporize o 50.';
      } else {
        verdict = 'Pico de inrush dentro do ajuste 50 '
            '(${fmtNumber(pickup, decimals: 0)} A).';
      }
    } else {
      verdict = est.harmonicBlockOk
          ? '2º harmônico (~${fmtNumber(est.secondHarmonicRatio, decimals: 0)}%) '
              'suficiente para o bloqueio típico (15%) do diferencial.'
          : '2º harmônico estimado abaixo de 15% — verifique o bloqueio.';
      bad = !est.harmonicBlockOk;
    }

    setState(() {
      _warning = null;
      _results = results;
      _verdict = verdict;
      _verdictBad = bad;
    });
  }

  Widget _inrushRealCard() {
    return ToolCard(
      title: AppLocalizations.of(context)!.equipmentInrushReal,
      subtitle:
          AppLocalizations.of(context)!.equipmentTransfDesc,
      children: [
        ToolFieldRow(children: [
          ToolField(controller: _irPower, label: AppLocalizations.of(context)!.equipmentPower),
          ToolField(controller: _irVolt, label: AppLocalizations.of(context)!.equipmentVEnergized),
        ]),
        const SizedBox(height: 12),
        ToolFieldRow(children: [
          ToolField(controller: _irZcc, label: AppLocalizations.of(context)!.equipmentZShort),
          ToolField(controller: _irResidual, label: AppLocalizations.of(context)!.equipmentFlux),
        ]),
        const SizedBox(height: 12),
        ToolField(controller: _irPickup50, label: AppLocalizations.of(context)!.equipmentAdjust50),
      ],
    );
  }

  Widget _bankCard() {
    return Column(
      children: [
        ToolCard(
          title: AppLocalizations.of(context)!.equipmentTransfBank,
          subtitle:
              AppLocalizations.of(context)!.equipmentBankDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _bankVolt, label: AppLocalizations.of(context)!.equipmentBankV),
              ToolField(
                  controller: _coincidence, label: AppLocalizations.of(context)!.equipmentBankCoin),
            ]),
            const SizedBox(height: 12),
            ToolField(
                controller: _pickup50,
                label: AppLocalizations.of(context)!.equipmentAdjust50Up),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.equipmentTransfList,
          children: [
            for (var i = 0; i < _bankRows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ToolField(
                        controller: _bankRows[i].kva,
                        label: 'Trafo ${i + 1} — kVA',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ToolField(
                        controller: _bankRows[i].factor,
                        label: AppLocalizations.of(context)!.equipmentInrush,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppColors.textMuted, size: 22),
                      tooltip: 'Remover',
                      onPressed: _bankRows.length > 1
                          ? () => _removeRow(i)
                          : null,
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: Text(AppLocalizations.of(context)!.equipmentAddTransf),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _verdictBox(String text, bool bad) {
    final color = bad ? AppColors.warning : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(bad ? Icons.error_outline : Icons.check_circle_outline,
              color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: color, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
