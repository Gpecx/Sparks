import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/iec61850.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class Iec61850Screen extends StatefulWidget {
  const Iec61850Screen({super.key});

  @override
  State<Iec61850Screen> createState() => _Iec61850ScreenState();
}

class _Iec61850ScreenState extends State<Iec61850Screen> {
  int _mode = 0; // 0 = timing (GOOSE/SV), 1 = endereçamento

  // GOOSE timing
  final _t1 = TextEditingController(text: '4');
  final _t0 = TextEditingController(text: '1000');
  final _measured = TextEditingController(text: '2.5');
  GooseMessageClass _msgClass = gooseMessageClasses.first;

  // SV
  int _samplesPerCycle = 80;
  int _frequency = 60;

  // Endereçamento
  final _mac = TextEditingController(text: '01-0C-CD-01-00-01');
  final _appid = TextEditingController(text: '0001');
  final _vlan = TextEditingController(text: '100');
  final _priority = TextEditingController(text: '4');

  List<int>? _seq;
  bool? _timeOk;
  SvRate? _sv;
  AddressCheck? _addr;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_t1, _t0, _measured, _mac, _appid, _vlan, _priority]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _pd(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  int? _pi(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int? _piHex(TextEditingController c) {
    final t = c.text.trim().replaceAll('0x', '').replaceAll('0X', '');
    if (t.isEmpty) return null;
    return int.tryParse(t, radix: 16) ?? int.tryParse(t);
  }

  void _calcTiming() {
    final t1 = _pi(_t1);
    final t0 = _pi(_t0);
    final meas = _pd(_measured);
    if (t1 == null || t0 == null || t1 <= 0 || t0 <= 0) {
      setState(() {
        _warning = 'Informe T1 e T0 em ms (> 0).';
        _seq = null;
        _sv = null;
      });
      return;
    }
    setState(() {
      _warning = null;
      _seq = gooseRetransmissionSequence(t1Ms: t1, t0Ms: t0);
      _timeOk = meas == null
          ? null
          : gooseTimeOk(measuredMs: meas, maxTransferMs: _msgClass.maxTransferMs);
      _sv = svRate(samplesPerCycle: _samplesPerCycle, frequency: _frequency);
    });
  }

  void _calcAddressing() {
    final appid = _piHex(_appid);
    final vlan = _pi(_vlan);
    final prio = _pi(_priority);
    if (appid == null || vlan == null || prio == null) {
      setState(() {
        _warning = 'Preencha APPID (hex), VLAN-ID e prioridade.';
        _addr = null;
      });
      return;
    }
    setState(() {
      _warning = null;
      _addr = checkAddressing(
        mac: _mac.text, appid: appid, vlanId: vlan, priority: prio,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'IEC 61850 — GOOSE / SV',
      children: [
        _infoBox(),
        const SizedBox(height: 12),
        ToolSegmented(
          labels: const ['Timing', 'Endereçamento'],
          selected: _mode,
          onSelect: (i) => setState(() {
            _mode = i;
            _warning = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_mode == 0) ..._timingTab() else ..._addressingTab(),
      ],
    );
  }

  // ── Aba Timing ──────────────────────────────────────────────────
  List<Widget> _timingTab() {
    return [
      ToolCard(
        title: 'GOOSE — retransmissão',
        subtitle: 'Após o evento dobra de T1 até estabilizar em T0 (keep-alive).',
        children: [
          ToolFieldRow(children: [
            ToolField(controller: _t1, label: 'T1 pós-evento (ms)'),
            ToolField(controller: _t0, label: 'T0 estável (ms)'),
          ]),
          const SizedBox(height: 12),
          ToolField(controller: _measured, label: 'Tempo medido/estimado (ms)'),
          const SizedBox(height: 12),
          DropdownButtonFormField<GooseMessageClass>(
            initialValue: _msgClass,
            isExpanded: true,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            items: [
              for (final c in gooseMessageClasses)
                DropdownMenuItem(
                    value: c, child: Text('${c.name} — ${c.maxTransferMs.toStringAsFixed(0)} ms')),
            ],
            onChanged: (c) {
              if (c != null) setState(() => _msgClass = c);
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      ToolCard(
        title: 'Sampled Values',
        subtitle: 'Amostras por ciclo × frequência → pacotes/s e banda.',
        children: [
          Row(
            children: [
              Expanded(
                child: _segmentInt(
                  label: 'Amostras/ciclo',
                  value: _samplesPerCycle,
                  options: const [80, 256],
                  onSelect: (v) => setState(() => _samplesPerCycle = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _segmentInt(
                  label: 'Frequência',
                  value: _frequency,
                  options: const [50, 60],
                  onSelect: (v) => setState(() => _frequency = v),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 20),
      ToolButton(label: 'CALCULAR', onPressed: _calcTiming),
      if (_warning != null) ...[
        const SizedBox(height: 24),
        ToolResultsPanel(results: const [], warning: _warning),
      ],
      if (_seq != null) ...[
        const SizedBox(height: 24),
        if (_timeOk != null) _timeVerdict(),
        if (_timeOk != null) const SizedBox(height: 12),
        _timingResults(),
      ],
    ];
  }

  Widget _timeVerdict() {
    final ok = _timeOk!;
    final color = ok ? AppColors.primary : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'Tempo dentro do requisito (${_msgClass.maxTransferMs.toStringAsFixed(0)} ms)'
                  : 'Tempo ACIMA do requisito (${_msgClass.maxTransferMs.toStringAsFixed(0)} ms) — revisar rede/IED',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timingResults() {
    final results = <ToolResult>[
      ToolResult('Sequência GOOSE (ms)', _seq!.join(' → ')),
      ToolResult('Nº de retransmissões até T0', '${_seq!.length}'),
      if (_sv != null) ...[
        ToolResult('SV — amostras/s', '${_sv!.samplesPerSecond}'),
        ToolResult('SV — pacotes/s', '${_sv!.packetsPerSecond}'),
        ToolResult('SV — banda estimada', '${fmtNumber(_sv!.estimatedMbps, decimals: 2)} Mbit/s'),
      ],
    ];
    return ToolResultsPanel(
      results: results,
      title: 'Timing GOOSE / SV',
      note: 'Sequência típica de retransmissão e taxa de SV. Confirme os tempos '
          'reais com um analisador de rede no comissionamento.',
    );
  }

  // ── Aba Endereçamento ───────────────────────────────────────────
  List<Widget> _addressingTab() {
    return [
      ToolCard(
        title: 'Endereçamento multicast',
        subtitle:
            'GOOSE: 01-0C-CD-01-xx-xx · SV: 01-0C-CD-04-xx-xx. VLAN 0–4094, '
            'prioridade 0–7.',
        children: [
          ToolField(controller: _mac, label: 'MAC multicast'),
          const SizedBox(height: 12),
          ToolFieldRow(children: [
            ToolField(controller: _appid, label: 'APPID (hex)'),
            ToolField(controller: _vlan, label: 'VLAN-ID'),
            ToolField(controller: _priority, label: 'Prioridade'),
          ]),
        ],
      ),
      const SizedBox(height: 20),
      ToolButton(label: 'VERIFICAR', onPressed: _calcAddressing),
      if (_warning != null) ...[
        const SizedBox(height: 24),
        ToolResultsPanel(results: const [], warning: _warning),
      ],
      if (_addr != null) ...[
        const SizedBox(height: 24),
        _addrVerdict(_addr!),
        const SizedBox(height: 12),
        _addrResults(_addr!),
      ],
    ];
  }

  Widget _addrVerdict(AddressCheck c) {
    final ok = c.allOk;
    final color = ok ? AppColors.primary : AppColors.warning;
    final kindLabel = c.kind == MulticastKind.goose
        ? 'GOOSE'
        : c.kind == MulticastKind.sampledValues
            ? 'Sampled Values'
            : 'fora das faixas 61850';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.verified_outlined : Icons.report_problem_outlined,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'Endereçamento OK — MAC de $kindLabel'
                  : 'Endereçamento com problema — MAC: $kindLabel',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addrResults(AddressCheck c) {
    String yn(bool b) => b ? 'OK' : 'verificar';
    final results = <ToolResult>[
      ToolResult('MAC multicast 61850', yn(c.macValid)),
      ToolResult('Tipo de MAC',
          c.kind == MulticastKind.goose
              ? 'GOOSE'
              : c.kind == MulticastKind.sampledValues
                  ? 'SV'
                  : 'desconhecido'),
      ToolResult('APPID (0x0000–0xFFFF)', yn(c.appidValid)),
      ToolResult('VLAN-ID (0–4094)', yn(c.vlanValid)),
      ToolResult('Prioridade (0–7)', yn(c.priorityValid)),
    ];
    return ToolResultsPanel(
      results: results,
      title: 'Verificação de endereçamento',
      note: 'Faixas reservadas da IEC 61850-8-1 (GOOSE) e 9-2 (SV). Um MAC fora '
          'da faixa ou VLAN errada costuma derrubar a subscrição no SCD.',
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────
  Widget _segmentInt({
    required String label,
    required int value,
    required List<int> options,
    required ValueChanged<int> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        ToolSegmented(
          labels: options.map((e) => '$e').toList(),
          selected: options.indexOf(value).clamp(0, options.length - 1),
          onSelect: (i) => onSelect(options[i]),
        ),
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
          const Icon(Icons.lan_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Triagem de GOOSE/SV no comissionamento IEC 61850: sequência de '
              'retransmissão, taxa de Sampled Values e endereçamento multicast '
              '(MAC/APPID/VLAN). Confirme no analisador de rede.',
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
