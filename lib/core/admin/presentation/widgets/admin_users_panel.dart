import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/access_code_service.dart';

/// Painel admin: lista todos os usuários com o plano/origem de acesso
/// (assinatura, voucher de cortesia, premium ou free), nome, email e validade.
class AdminUsersPanel extends StatefulWidget {
  const AdminUsersPanel({super.key});

  @override
  State<AdminUsersPanel> createState() => _AdminUsersPanelState();
}

class _AdminUsersPanelState extends State<AdminUsersPanel> {
  final _service = AccessCodeService.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String _query = '';
  String _filter = 'all'; // all | subscription | voucher | premium | free

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
      final users = await _service.listUsers();
      if (!mounted) return;
      // Ordena por XP semanal desc (mais ativos primeiro).
      users.sort((a, b) =>
          ((b['weeklyXp'] ?? 0) as num).compareTo((a['weeklyXp'] ?? 0) as num));
      setState(() {
        _users = users;
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

  List<Map<String, dynamic>> get _filtered {
    return _users.where((u) {
      if (_filter != 'all' && (u['plan'] ?? 'free') != _filter) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final name = (u['name'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  // ── Metadados de plano (rótulo + cor) ───────────────────────────
  ({String label, Color color}) _planMeta(String plan) {
    switch (plan) {
      case 'subscription':
        return (label: 'Assinatura', color: const Color(0xFF22C55E));
      case 'voucher':
        return (label: 'Voucher', color: const Color(0xFFFFB020));
      case 'premium':
        return (label: 'Premium', color: AppColors.primary);
      default:
        return (label: 'Free', color: AppColors.textMuted);
    }
  }

  int _countPlan(String plan) =>
      _users.where((u) => (u['plan'] ?? 'free') == plan).length;

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
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
                  Text('Usuários',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('Veja todos os usuários, seus planos e quem entrou por voucher.',
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
        _buildFilters(),
        const SizedBox(height: 16),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildFilters() {
    Widget chip(String value, String label, [int? count]) {
      final active = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(count != null ? '$label ($count)' : label),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Buscar por nome ou email…',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('all', 'Todos', _users.length),
              chip('subscription', 'Assinatura', _countPlan('subscription')),
              chip('voucher', 'Voucher', _countPlan('voucher')),
              chip('premium', 'Premium', _countPlan('premium')),
              chip('free', 'Free', _countPlan('free')),
            ],
          ),
        ),
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
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(
        child: Text('Nenhum usuário encontrado.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _userRow(list[i]),
    );
  }

  Widget _userRow(Map<String, dynamic> u) {
    final name = (u['name'] as String?)?.trim();
    final email = u['email'] as String?;
    final plan = (u['plan'] as String?) ?? 'free';
    final meta = _planMeta(plan);
    final code = u['compAccessCode'] as String?;
    final exp = _fmtDate(u['compAccessExpiresAt'] as String?);
    final isAdmin = (u['role'] as String?) == 'admin';
    final display = (name != null && name.isNotEmpty)
        ? name
        : (email ?? (u['uid'] as String? ?? 'Usuário'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: meta.color.withValues(alpha: 0.18),
            child: Text(
              display.isNotEmpty ? display[0].toUpperCase() : '?',
              style: TextStyle(color: meta.color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.shield, size: 13, color: AppColors.primary),
                    ],
                  ],
                ),
                if (email != null && email.isNotEmpty)
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (plan == 'voucher' && (code != null || exp.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (code != null && code.isNotEmpty) 'Código $code',
                        if (exp.isNotEmpty) 'até $exp',
                      ].join(' · '),
                      style: const TextStyle(
                          color: Color(0xFFFFB020), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(meta.label,
                style: TextStyle(
                    color: meta.color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
