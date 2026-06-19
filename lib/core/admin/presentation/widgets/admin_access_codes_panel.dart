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
  String _filter = 'all'; // all | available | redeemed | revoked

  // Status de um código: 'revoked' | 'redeemed' | 'available'.
  String _statusOf(Map<String, dynamic> c) {
    final active = c['active'] == true;
    final used = (c['usedCount'] ?? 0) as int;
    final maxUses = (c['maxUses'] ?? 1) as int;
    if (!active) return 'revoked';
    if (used >= maxUses) return 'redeemed';
    return 'available';
  }

  int _countStatus(String s) => _codes.where((c) => _statusOf(c) == s).length;

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _codes;
    return _codes.where((c) => _statusOf(c) == _filter).toList();
  }

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

  /// Abre o diálogo para anotar/editar para quem o voucher foi enviado.
  Future<void> _editNote(Map<String, dynamic> c) async {
    final code = c['code']?.toString() ?? '';
    if (code.isEmpty) return;
    final noteCtrl = TextEditingController(text: (c['note'] as String?) ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(code,
                  style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Para quem este voucher foi enviado?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 280,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ex.: enviado p/ Maria (Escola X) via WhatsApp',
                hintStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.textMuted)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    try {
      await _service.setNote(code, noteCtrl.text.trim());
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(e.toString())),
      );
    }
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

  /// Formata os resgatadores de um código: "Nome (email)" por pessoa.
  /// Cai para o email, ou um uid encurtado, quando o nome não está disponível.
  String _redeemersLabel(List redeemers, List redeemedBy) {
    if (redeemers.isNotEmpty) {
      return redeemers.map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final name = (m['name'] as String?)?.trim() ?? '';
        final email = (m['email'] as String?)?.trim() ?? '';
        final uid = (m['uid'] as String?) ?? '';
        if (name.isNotEmpty && email.isNotEmpty) return '$name ($email)';
        if (name.isNotEmpty) return name;
        if (email.isNotEmpty) return email;
        return uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
      }).join(', ');
    }
    // Fallback: só temos os uids (resposta antiga do backend).
    return redeemedBy
        .map((u) => u.toString())
        .map((u) => u.length > 8 ? '${u.substring(0, 8)}…' : u)
        .join(', ');
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
        const SizedBox(height: 16),
        _buildStatusFilter(),
        const SizedBox(height: 16),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildStatusFilter() {
    Widget chip(String value, String label, int count) {
      final active = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: active,
          onSelected: (_) => setState(() => _filter = value),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primary.withValues(alpha: 0.25),
          labelStyle: TextStyle(
              color: active ? AppColors.primary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
          side: BorderSide(
              color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.08)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('all', 'Todos', _codes.length),
          chip('available', 'Disponível', _countStatus('available')),
          chip('redeemed', 'Resgatado', _countStatus('redeemed')),
          chip('revoked', 'Revogado', _countStatus('revoked')),
        ],
      ),
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
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(
        child: Text('Nenhum código neste filtro.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = list[i];
        final active = c['active'] == true;
        final used = (c['usedCount'] ?? 0) as int;
        final maxUses = (c['maxUses'] ?? 1) as int;
        final redeemed = (c['redeemedBy'] as List?) ?? const [];
        final redeemers = (c['redeemers'] as List?) ?? const [];
        final label = c['label'] as String?;
        final note = (c['note'] as String?)?.trim() ?? '';
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

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _editNote(c),
            child: Container(
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
                          '${label != null && label.isNotEmpty ? ' · $label' : ''}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        if (redeemers.isNotEmpty || redeemed.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.person, size: 13, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Resgatado por: ${_redeemersLabel(redeemers, redeemed)}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.sticky_note_2_outlined,
                                size: 13,
                                color: note.isNotEmpty
                                    ? AppColors.warningAmber
                                    : AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                note.isNotEmpty ? note : 'Toque para anotar p/ quem foi enviado',
                                style: TextStyle(
                                  color: note.isNotEmpty
                                      ? AppColors.warningAmber
                                      : AppColors.textMuted,
                                  fontSize: 12,
                                  fontStyle: note.isNotEmpty
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
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
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => _editNote(c),
                    icon: const Icon(Icons.edit_note, size: 20, color: AppColors.textSecondary),
                    tooltip: 'Anotar destinatário',
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
            ),
          ),
        );
      },
    );
  }
}
