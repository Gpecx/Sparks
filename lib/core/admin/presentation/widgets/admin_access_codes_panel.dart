import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/access_code_service.dart';

/// Painel admin para gerar, listar e revogar códigos de acesso (cortesia).
class AdminAccessCodesPanel extends StatefulWidget {
  const AdminAccessCodesPanel({super.key});

  @override
  State<AdminAccessCodesPanel> createState() => _AdminAccessCodesPanelState();
}

class _AdminAccessCodesPanelState extends State<AdminAccessCodesPanel> {
  final _service = AccessCodeService.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _codes = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final codes = await _service.listCodes();
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showGenerateDialog() async {
    final countCtrl = TextEditingController(text: '5');
    final daysCtrl = TextEditingController(text: '30');
    final labelCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Gerar códigos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(countCtrl, 'Quantidade (1–100)', TextInputType.number),
            const SizedBox(height: 12),
            _field(daysCtrl, 'Duração (dias)', TextInputType.number),
            const SizedBox(height: 12),
            _field(labelCtrl, 'Rótulo (opcional)', TextInputType.text),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () async {
              final count = int.tryParse(countCtrl.text.trim()) ?? 0;
              final days = int.tryParse(daysCtrl.text.trim()) ?? 30;
              if (count < 1) return;
              Navigator.of(ctx).pop();
              await _generate(count, days, labelCtrl.text.trim());
            },
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
  }

  Future<void> _generate(int count, int days, String label) async {
    try {
      final codes = await _service.createCodes(
        count: count,
        durationDays: days,
        label: label.isEmpty ? null : label,
      );
      if (!mounted) return;
      await _showGeneratedDialog(codes);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(e.toString())),
      );
    }
  }

  Future<void> _showGeneratedDialog(List<String> codes) async {
    final all = codes.join('\n');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('${codes.length} código(s) gerado(s)',
            style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(all,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'monospace',
                        height: 1.6)),
              ),
              const SizedBox(height: 8),
              const Text('Copie e distribua aos professores.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: all));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Códigos copiados.')),
              );
            },
            child: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _copyCode(String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Código $code copiado.')),
    );
  }

  Future<void> _revoke(String code) async {
    try {
      await _service.revoke(code);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(e.toString())),
      );
    }
  }

  Widget _field(TextEditingController c, String label, TextInputType type) {
    return TextField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.textMuted)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Códigos de Acesso',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('Gere e gerencie códigos de cortesia para professores.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
              tooltip: 'Atualizar',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showGenerateDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('GERAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(110, 40),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text('Erro: $_error', style: const TextStyle(color: AppColors.error)),
      );
    }
    if (_codes.isEmpty) {
      return const Center(
        child: Text('Nenhum código gerado ainda.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: _codes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = _codes[i];
        final active = c['active'] == true;
        final used = (c['usedCount'] ?? 0) as int;
        final maxUses = (c['maxUses'] ?? 1) as int;
        final redeemed = (c['redeemedBy'] as List?) ?? const [];
        final label = c['label'] as String?;
        final exhausted = used >= maxUses;
        final status = !active
            ? 'Revogado'
            : exhausted
                ? 'Resgatado'
                : 'Disponível';
        final statusColor = !active
            ? AppColors.error
            : exhausted
                ? AppColors.textMuted
                : AppColors.primary;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['code']?.toString() ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(
                      '${c['durationDays'] ?? 30} dias · $used/$maxUses uso(s)'
                      '${label != null && label.isNotEmpty ? ' · $label' : ''}'
                      '${redeemed.isNotEmpty ? ' · por ${redeemed.first}' : ''}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: () => _copyCode(c['code']?.toString() ?? ''),
                icon: const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
                tooltip: 'Copiar código',
              ),
              if (active && !exhausted)
                IconButton(
                  onPressed: () => _revoke(c['code'].toString()),
                  icon: const Icon(Icons.block, size: 18, color: AppColors.error),
                  tooltip: 'Revogar',
                ),
            ],
          ),
        );
      },
    );
  }
}
