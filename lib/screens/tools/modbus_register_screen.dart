import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/modbus_register.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class ModbusRegisterScreen extends StatefulWidget {
  const ModbusRegisterScreen({super.key});

  @override
  State<ModbusRegisterScreen> createState() => _ModbusRegisterScreenState();
}

class _ModbusRegisterScreenState extends State<ModbusRegisterScreen> {
  final _reg0 = TextEditingController(text: '42C8');
  final _reg1 = TextEditingController(text: '0000');
  ByteOrder _order = ByteOrder.abcd;

  ModbusDecode? _result;
  Map<ByteOrder, ModbusDecode>? _all;
  String? _warning;

  @override
  void dispose() {
    _reg0.dispose();
    _reg1.dispose();
    super.dispose();
  }

  int? _parseReg(TextEditingController c) {
    var t = c.text.trim().replaceAll('0x', '').replaceAll('0X', '');
    if (t.isEmpty) return null;
    final v = int.tryParse(t, radix: 16);
    if (v == null || v < 0 || v > 0xFFFF) return null;
    return v;
  }

  void _calculate() {
    final r0 = _parseReg(_reg0);
    final r1 = _parseReg(_reg1);
    if (r0 == null || r1 == null) {
      setState(() {
        _warning = 'Informe 2 registradores em hexadecimal (0000–FFFF).';
        _result = null;
        _all = null;
      });
      return;
    }
    setState(() {
      _warning = null;
      _result = decodeRegisters(r0, r1, _order);
      _all = decodeAllOrders(r0, r1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Modbus — Registradores',
      children: [
        _infoBox(),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Registradores (16 bits, hex)',
          subtitle: 'reg0 = 1º registrador lido · reg1 = 2º. A/B = bytes de reg0; '
              'C/D = bytes de reg1.',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _reg0, label: 'Reg 0 (hex)'),
              ToolField(controller: _reg1, label: 'Reg 1 (hex)'),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Ordem de byte/word',
          children: [
            ToolSegmented(
              labels: const ['ABCD', 'CDAB', 'BADC', 'DCBA'],
              selected: _order.index,
              onSelect: (i) => setState(() {
                _order = ByteOrder.values[i];
                if (_result != null) _calculate();
              }),
            ),
            const SizedBox(height: 8),
            Text(
              byteOrderLabel(_order),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'DECODIFICAR', onPressed: _calculate),
        if (_warning != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: const [], warning: _warning),
        ],
        if (_result != null) ...[
          const SizedBox(height: 24),
          _decodeResults(_result!),
          const SizedBox(height: 16),
          _allOrdersCard(_all!),
        ],
      ],
    );
  }

  Widget _decodeResults(ModbusDecode d) {
    final results = <ToolResult>[
      ToolResult('Bytes (ordem aplicada)', d.hex),
      ToolResult('Float 32 (IEEE-754)', _fmtFloat(d.float32)),
      ToolResult('Int 32 (com sinal)', '${d.int32}'),
      ToolResult('UInt 32 (sem sinal)', '${d.uint32}'),
    ];
    return ToolResultsPanel(
      results: results,
      title: 'Valor decodificado (${byteOrderLabel(_order)})',
    );
  }

  Widget _allOrdersCard(Map<ByteOrder, ModbusDecode> all) {
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
            'Float em todas as ordens',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Compare com o valor esperado para descobrir a ordem certa do medidor.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...ByteOrder.values.map((o) {
            final d = all[o]!;
            final selected = o == _order;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      byteOrderLabel(o),
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _fmtFloat(d.float32),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmtFloat(double v) {
    if (v.isNaN) return 'NaN';
    if (v.isInfinite) return v.isNegative ? '-∞' : '∞';
    if (v != 0 && (v.abs() >= 1e6 || v.abs() < 1e-3)) {
      return v.toStringAsExponential(4);
    }
    return v.toStringAsFixed(4);
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
          const Icon(Icons.memory_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Junta 2 registradores de 16 bits em float32/int32 com a ordem de '
              'byte/word do medidor. Quando o valor "vem absurdo", é quase sempre '
              'a ordem errada — veja a tabela com as 4 ordens.',
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
