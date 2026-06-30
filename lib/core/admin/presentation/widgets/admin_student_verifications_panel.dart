import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/student_verification_service.dart';

/// Painel admin para revisar (aprovar/rejeitar) as verificações de
/// matrícula do plano Student (PDF §8).
class AdminStudentVerificationsPanel extends StatefulWidget {
  const AdminStudentVerificationsPanel({super.key});

  @override
  State<AdminStudentVerificationsPanel> createState() =>
      _AdminStudentVerificationsPanelState();
}

class _AdminStudentVerificationsPanelState
    extends State<AdminStudentVerificationsPanel> {
  final _service = StudentVerificationService.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'pending'; // pending | approved | rejected | all

  int _countStatus(String s) =>
      _items.where((v) => (v['status'] ?? 'pending') == s).length;

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((v) => (v['status'] ?? 'pending') == _filter).toList();
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
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _review(Map<String, dynamic> v, bool approve) async {
    final uid = v['uid']?.toString() ?? '';
    if (uid.isEmpty) return;
    final name = (v['name'] as String?)?.trim();
    final who = (name != null && name.isNotEmpty) ? name : uid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(approve ? 'Aprovar estudante' : 'Rejeitar estudante',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          approve
              ? 'Conceder o acesso ao plano Student para $who?'
              : 'Rejeitar a verificação de $who?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: approve ? AppColors.primary : AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(approve ? 'Aprovar' : 'Rejeitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (approve) {
        await _service.approve(uid);
      } else {
        await _service.reject(uid);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Estudante aprovado.' : 'Verificação rejeitada.')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(e.toString())),
      );
    }
  }

  Future<void> _openProof(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  static const _statusLabel = {
    'pending': 'Pendente',
    'approved': 'Aprovado',
    'rejected': 'Rejeitado',
  };

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return AppColors.primary;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warningAmber;
    }
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
                  Text('Verificações de Estudante',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('Aprove ou rejeite os comprovantes de matrícula do plano Student.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
              tooltip: 'Atualizar',
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
          chip('pending', 'Pendentes', _countStatus('pending')),
          chip('approved', 'Aprovados', _countStatus('approved')),
          chip('rejected', 'Rejeitados', _countStatus('rejected')),
          chip('all', 'Todos', _items.length),
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
    if (_items.isEmpty) {
      return const Center(
        child: Text('Nenhuma solicitação de verificação ainda.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(
        child: Text('Nenhuma solicitação neste filtro.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildRow(list[i]),
    );
  }

  Widget _buildRow(Map<String, dynamic> v) {
    final status = (v['status'] ?? 'pending').toString();
    final name = (v['name'] as String?)?.trim() ?? '';
    final accountEmail = (v['accountEmail'] as String?)?.trim() ?? '';
    final institution = (v['institution'] as String?)?.trim() ?? '';
    final instEmail = (v['institutionalEmail'] as String?)?.trim() ?? '';
    final proofUrl = (v['proofUrl'] as String?)?.trim() ?? '';
    final autoEligible = v['autoEligible'] == true;
    final color = _statusColor(status);
    final title = name.isNotEmpty
        ? name
        : (accountEmail.isNotEmpty ? accountEmail : (v['uid']?.toString() ?? ''));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              if (autoEligible)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('.edu.br',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel[status] ?? status,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (institution.isNotEmpty)
            _infoLine(Icons.school_outlined, institution),
          if (instEmail.isNotEmpty) _infoLine(Icons.alternate_email, instEmail),
          if (accountEmail.isNotEmpty && accountEmail != instEmail)
            _infoLine(Icons.person_outline, 'Conta: $accountEmail'),
          _infoLine(Icons.event_outlined, 'Enviado em ${_fmtDate(v['createdAt'] as String?)}'),
          const SizedBox(height: 12),
          Row(
            children: [
              if (proofUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openProof(proofUrl),
                  icon: const Icon(Icons.attachment, size: 16),
                  label: const Text('Ver comprovante'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.textMuted),
                  ),
                ),
              const Spacer(),
              if (status == 'pending') ...[
                TextButton(
                  onPressed: () => _review(v, false),
                  child: const Text('Rejeitar',
                      style: TextStyle(color: AppColors.error)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => _review(v, true),
                  child: const Text('Aprovar'),
                ),
              ] else
                TextButton(
                  onPressed: () => _review(v, status != 'approved'),
                  child: Text(
                    status == 'approved' ? 'Revogar' : 'Aprovar',
                    style: TextStyle(
                        color: status == 'approved'
                            ? AppColors.error
                            : AppColors.primary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
