import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';

enum ClanRole { chefe, admin, moderador, membro }

class ClanMember {
  final String name;
  final String position;
  final int xp;
  final ClanRole role;
  final bool isUser;
  const ClanMember({required this.name, required this.position, required this.xp, required this.role, this.isUser = false});
}

final List<ClanMember> _mockMembers = [
  const ClanMember(name: 'Alex Rodriguez', position: 'Técnico Líder', xp: 14250, role: ClanRole.chefe, isUser: true),
  const ClanMember(name: 'Mariana Figueiredo', position: 'Engenheira', xp: 12800, role: ClanRole.admin),
  const ClanMember(name: 'Bruno Carvalho', position: 'Técnico', xp: 9400, role: ClanRole.moderador),
  const ClanMember(name: 'Camila Santos', position: 'Analista', xp: 7600, role: ClanRole.membro),
  const ClanMember(name: 'Diego Oliveira', position: 'Estagiário', xp: 3200, role: ClanRole.membro),
];

class ClanScreen extends StatefulWidget {
  final bool isCreating;
  const ClanScreen({super.key, required this.isCreating});

  @override
  State<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends State<ClanScreen> {
  bool _clanCreated = false;
  String _clanName = 'EXS Técnicos';
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _joinPasswordCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _joinPasswordCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _clanCreated
                ? _clanName.toUpperCase()
                : widget.isCreating
                    ? 'CRIAR CLÃ'
                    : 'ENTRAR EM UM CLÃ',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.5),
          ),
          actions: _clanCreated
              ? [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: AppColors.card,
                    onSelected: (v) {
                      if (v == 'edit') _showEditClanDialog();
                      if (v == 'delete') _showDeleteDialog();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar Nome/Senha', style: TextStyle(color: Colors.white))),
                      const PopupMenuItem(value: 'delete', child: Text('Deletar Clã', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ]
              : null,
        ),
        body: _clanCreated
            ? _buildClanView()
            : widget.isCreating
                ? _buildCreateClan()
                : _buildJoinClan(),
      ),
    );
  }

  // ── CRIAR CLÃ ──────────────────────────────────────────────
  Widget _buildCreateClan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(Icons.groups, color: AppColors.primary, size: 52),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Crie um grupo para sua empresa e compete contra seus colegas!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                _label('Nome do Clã'),
                const SizedBox(height: 8),
                _inputField(_nameCtrl, 'Ex: EXS Técnicos SP', Icons.shield_outlined),
                const SizedBox(height: 16),
                _label('Senha do Clã'),
                const SizedBox(height: 8),
                _inputField(_passwordCtrl, 'Mínimo 4 caracteres', Icons.lock_outline, isPassword: true),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Como criador, você terá o cargo de CHEFE e poderá gerenciar todos os membros.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _createClan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CRIAR GRUPO/CLÃ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ENTRAR EM CLÃ ──────────────────────────────────────────
  Widget _buildJoinClan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Icon(Icons.login, color: AppColors.primary, size: 52)),
                const SizedBox(height: 16),
                const Text(
                  'Entre com código de convite ou com a senha do clã.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                _label('Código de Convite (opcional)'),
                const SizedBox(height: 8),
                _inputField(_joinCodeCtrl, 'Ex: SPARK-XK29', Icons.confirmation_number_outlined),
                const SizedBox(height: 16),
                _label('Senha do Clã'),
                const SizedBox(height: 8),
                _inputField(_joinPasswordCtrl, 'Digite a senha do grupo', Icons.lock_outline, isPassword: true),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _joinClan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ENTRAR NO GRUPO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── VISUALIZAÇÃO DO CLÃ ──────────────────────────────────────
  Widget _buildClanView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card do clã
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                  ),
                  child: const Icon(Icons.shield, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_clanName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${_mockMembers.length} membros · Criado hoje', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _showInviteDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Membros
          const Text('MEMBROS', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 10),
          ..._mockMembers.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return _MemberTile(member: m, rank: i + 1, onManage: () => _showManageDialog(m));
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  void _createClan() {
    if (_nameCtrl.text.trim().isEmpty || _passwordCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e a senha (mín. 4 caracteres)!'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() {
      _clanName = _nameCtrl.text.trim();
      _clanCreated = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Clã "$_clanName" criado com sucesso!'), backgroundColor: AppColors.primary),
    );
  }

  void _joinClan() {
    if (_joinPasswordCtrl.text.isEmpty && _joinCodeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a senha ou código de convite!'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() {
      _clanName = 'EXS Técnicos';
      _clanCreated = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Você entrou no clã!'), backgroundColor: AppColors.primary),
    );
  }

  void _showEditClanDialog() {
    final editCtrl = TextEditingController(text: _clanName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.primary)),
        title: const Text('Editar Clã', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Novo nome do clã',
                hintStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              setState(() => _clanName = editCtrl.text.trim().isEmpty ? _clanName : editCtrl.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('SALVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.error)),
        title: const Text('Deletar Clã?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Esta ação é permanente! Todos os membros serão removidos.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('DELETAR', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.primary)),
        title: const Text('Convidar Membro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compartilhe o código abaixo para convidar alguém:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.4))),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('SPARK-XK29', style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 4)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado!')));},
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('COPIAR CÓDIGO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showManageDialog(ClanMember member) {
    if (member.isUser) return; // Não pode gerenciar a si mesmo
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.cardBorder)),
        title: Text(member.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cargo atual: ${_roleName(member.role)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('Ações:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _actionTile(ctx, Icons.arrow_upward, 'Promover Cargo', AppColors.primary),
            _actionTile(ctx, Icons.arrow_downward, 'Rebaixar Cargo', AppColors.error),
            _actionTile(ctx, Icons.person_remove_outlined, 'Expulsar do Clã', AppColors.error),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
        ],
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, Color color) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label executado!'), backgroundColor: AppColors.primary));
      },
    );
  }

  String _roleName(ClanRole role) {
    switch (role) {
      case ClanRole.chefe: return 'Chefe';
      case ClanRole.admin: return 'Admin';
      case ClanRole.moderador: return 'Moderador';
      case ClanRole.membro: return 'Membro';
    }
  }
}

// ── TILE DE MEMBRO ───────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final ClanMember member;
  final int rank;
  final VoidCallback onManage;
  const _MemberTile({required this.member, required this.rank, required this.onManage});

  @override
  Widget build(BuildContext context) {
    Color roleColor;
    IconData roleIcon;
    switch (member.role) {
      case ClanRole.chefe:
        roleColor = AppColors.gold; roleIcon = Icons.workspace_premium; break;
      case ClanRole.admin:
        roleColor = AppColors.primary; roleIcon = Icons.admin_panel_settings; break;
      case ClanRole.moderador:
        roleColor = AppColors.accent; roleIcon = Icons.shield; break;
      default:
        roleColor = AppColors.textMuted; roleIcon = Icons.person; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: member.isUser ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: member.isUser ? AppColors.primary.withValues(alpha: 0.35) : AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$rank', style: TextStyle(color: rank <= 3 ? AppColors.gold : AppColors.textMuted, fontWeight: FontWeight.w800, fontSize: 15))),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: roleColor.withValues(alpha: 0.15), border: Border.all(color: roleColor.withValues(alpha: 0.4))),
            child: Icon(Icons.person, color: roleColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (member.isUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Você', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(roleIcon, color: roleColor, size: 12),
                    const SizedBox(width: 4),
                    Text(_roleLabelOf(member.role), style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('· ${member.xp} XP', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          if (!member.isUser)
            GestureDetector(
              onTap: onManage,
              child: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
            ),
        ],
      ),
    );
  }

  String _roleLabelOf(ClanRole role) {
    switch (role) {
      case ClanRole.chefe: return 'Chefe';
      case ClanRole.admin: return 'Admin';
      case ClanRole.moderador: return 'Moderador';
      default: return 'Membro';
    }
  }
}
