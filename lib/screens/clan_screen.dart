import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/services/clan_service.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

enum ClanRole { chefe, admin, moderador, membro }

class ClanMember {
  final String name;
  final String position;
  final int xp;
  final ClanRole role;
  final bool isUser;
  const ClanMember({required this.name, required this.position, required this.xp, required this.role, this.isUser = false});
}

class ClanQuest {
  final String id;
  final String title;
  final int currentProgress;
  final int targetProgress;
  final String rewardDescription;

  const ClanQuest({
     required this.id,
     required this.title,
     required this.currentProgress,
     required this.targetProgress,
     required this.rewardDescription,
  });

  bool get isCompleted => currentProgress >= targetProgress;
  double get progressPercentage => (currentProgress / targetProgress).clamp(0.0, 1.0);
}

final List<ClanMember> _mockMembers = [
  const ClanMember(name: 'Alex Rodriguez', position: 'Técnico Líder', xp: 14250, role: ClanRole.chefe, isUser: true),
  const ClanMember(name: 'Mariana Figueiredo', position: 'Engenheira', xp: 12800, role: ClanRole.admin),
  const ClanMember(name: 'Bruno Carvalho', position: 'Técnico', xp: 9400, role: ClanRole.moderador),
  const ClanMember(name: 'Camila Santos', position: 'Analista', xp: 7600, role: ClanRole.membro),
  const ClanMember(name: 'Diego Oliveira', position: 'Estagiário', xp: 3200, role: ClanRole.membro),
];

final List<ClanQuest> _mockQuests = [
  const ClanQuest(id: 'q1', title: 'Semana de Segurança', currentProgress: 15, targetProgress: 20, rewardDescription: '+ 5.000 XP'),
  const ClanQuest(id: 'q2', title: 'Mestres do Duelo', currentProgress: 10, targetProgress: 10, rewardDescription: '+ 2.500 XP'),
];

class ClanScreen extends StatefulWidget {
  final bool isCreating;
  final bool isViewingActive;
  const ClanScreen({super.key, this.isCreating = false, this.isViewingActive = false});

  @override
  State<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends State<ClanScreen> {
  bool _clanCreated = false;
  String _clanName = 'Carregando...';
  String? _myClanId;
  String? _currentUserUid;
  String? _myName;
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _joinPasswordCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();

  final _formKeyCreate = GlobalKey<FormState>();
  final _formKeyJoin = GlobalKey<FormState>();

  Color _clanPrimaryColor = AppColors.primary;
  IconData _clanIcon = Icons.shield;

  final List<Map<String, dynamic>> _messages = [
    {'sender': 'Sistema', 'text': 'Mariana subiu para o Rank Ouro!', 'isMe': false, 'isSystem': true},
    {'sender': 'Alex Rodriguez', 'text': 'Chegamos ao top 3 global!', 'isMe': false, 'isSystem': false},
    {'sender': 'Mariana Figueiredo', 'text': 'Vamos focar na meta dessa semana pessoal.', 'isMe': false, 'isSystem': false},
  ];
  final _chatCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    _myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Usuário';

    if (widget.isViewingActive) {
      _clanCreated = true;
      _clanName = 'EXS Técnicos';
    } else {
      _loadUserClan();
    }
  }

  Future<void> _loadUserClan() async {
    if (_currentUserUid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final clanId = data['clanId'];
        if (clanId != null) {
          final clanDoc = await FirebaseFirestore.instance.collection('clans').doc(clanId).get();
          if (mounted && clanDoc.exists) {
            setState(() {
              _myClanId = clanId;
              _clanName = clanDoc.data()?['name'] ?? 'Clã Atual';
              _clanCreated = true;
            });
          }
        }
      }
    } catch(e) {
      debugPrint('Erro carregando clã: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _joinPasswordCtrl.dispose();
    _joinCodeCtrl.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
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
                Form(
                  key: _formKeyCreate,
                  child: Column(
                    children: [
                      _inputField(
                        _nameCtrl, 
                        'Ex: EXS Técnicos SP', 
                        Icons.shield_outlined,
                        validator: (v) => (v == null || v.trim().length <= 3) ? 'Nome deve ter mais que 3 caracteres' : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Senha do Clã'),
                      const SizedBox(height: 8),
                      _inputField(
                        _passwordCtrl, 
                        'Mínimo 4 caracteres', 
                        Icons.lock_outline, 
                        isPassword: true,
                        validator: (v) => (v == null || v.trim().length < 4) ? 'Senha deve ter pelo menos 4 caracteres' : null,
                      ),
                    ],
                  ),
                ),
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
                Form(
                  key: _formKeyJoin,
                  child: Column(
                    children: [
                      _inputField(_joinCodeCtrl, 'Ex: SPARK-XK29', Icons.confirmation_number_outlined),
                      const SizedBox(height: 16),
                      _label('Senha do Clã'),
                      const SizedBox(height: 8),
                      _inputField(
                        _joinPasswordCtrl, 
                        'Digite a senha do grupo', 
                        Icons.lock_outline, 
                        isPassword: true,
                        validator: (v) => (_joinCodeCtrl.text.isEmpty && (v == null || v.isEmpty)) ? 'Informe a senha ou o código' : null,
                      ),
                    ],
                  ),
                ),
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
              border: Border.all(color: _clanPrimaryColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                _buildClanMascot(_mockMembers.fold(0, (sum, m) => sum + m.xp)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_clanName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${_mockMembers.length} membros · Criado há 2 dias', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 12),
                      // Barra de Level do Clã
                      Row(
                        children: [
                          const Text('Nível 4', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: const LinearProgressIndicator(
                                value: 0.65,
                                minHeight: 6,
                                backgroundColor: Color(0xFF1a1a1a),
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('6k/10k XP', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showInviteDialog,
                    borderRadius: BorderRadius.circular(8),
                    splashColor: AppColors.primary.withValues(alpha: 0.2),
                    highlightColor: AppColors.primary.withValues(alpha: 0.1),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _clanPrimaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _clanPrimaryColor.withValues(alpha: 0.4)),
                        ),
                        child: Icon(Icons.person_add_alt_1, color: _clanPrimaryColor, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // ESTATÍSTICAS DO CLÃ
          _buildClanStats(),
          const SizedBox(height: 20),

          // MISSÕES DA SEMANA
          _buildClanQuests(),
          const SizedBox(height: 20),

          // Membros
          const Text('MEMBROS', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 10),
          _myClanId == null 
             ? const CircularProgressIndicator()
             : StreamBuilder<QuerySnapshot>(
                 stream: FirebaseFirestore.instance.collection('clans').doc(_myClanId).collection('members').orderBy('xpContribution', descending: true).snapshots(),
                 builder: (context, snapshot) {
                   if (!snapshot.hasData) return const CircularProgressIndicator();
                   final docs = snapshot.data!.docs;
                   return Column(
                     children: docs.asMap().entries.map((entry) {
                       final i = entry.key;
                       final doc = entry.value;
                       final mData = doc.data() as Map<String, dynamic>;
                       final roleStr = mData['role'] as String? ?? 'membro';
                       final roleEnum = roleStr == 'chefe' ? ClanRole.chefe : (roleStr == 'admin' ? ClanRole.admin : (roleStr == 'moderador' ? ClanRole.moderador : ClanRole.membro));
                       final uid = mData['uid'];
                       
                       // Em app real buscaria o nome via uid num join rápido, 
                       // Por simplicidade provisória usando docId(se possuir) ou Fallback:
                       final mockMember = ClanMember(
                         name: uid == _currentUserUid ? 'Eu' : 'Membro $uid'.substring(0, 12), 
                         position: roleStr.toUpperCase(), 
                         xp: mData['xpContribution'] ?? 0, 
                         role: roleEnum,
                         isUser: uid == _currentUserUid,
                       );
                       return _MemberTile(member: mockMember, rank: i + 1, onManage: () => _showManageDialog(mockMember));
                     }).toList(),
                   );
                 },
               ),
          const SizedBox(height: 30),
          if (_myClanId != null) _buildChatSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildClanStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard('Liga Atual', 'OURO III', Icons.emoji_events, AppColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard('Rank Global', '#142', Icons.public, AppColors.primary),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CHAT DO CLÃ', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 10),
        Container(
          height: 350,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ClanService().watchMessages(_myClanId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    final msgs = snapshot.data ?? [];
                    if (msgs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.speaker_notes_off_outlined, color: AppColors.primary.withValues(alpha: 0.2), size: 64),
                            const SizedBox(height: 12),
                            const Text('O chat está silencioso...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Seja o primeiro a interagir!', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                        controller: _scrollCtrl,
                        reverse: true, // as mensagens mais novas estão no topo do array vindo do Firebase com descending: true
                        padding: const EdgeInsets.all(12),
                        itemCount: msgs.length,
                        itemBuilder: (ctx, i) {
                          final msg = msgs[i];
                          final isMe = msg['uid'] == _currentUserUid;
                          final isSystem = msg['isSystem'] == true;
                          
                          if (isSystem) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.info_outline, color: AppColors.gold, size: 14),
                                  const SizedBox(width: 6),
                                  Text(msg['text'] ?? '', style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.primary.withValues(alpha: 0.2) : AppColors.inputBackground,
                                border: Border.all(color: isMe ? AppColors.primary.withValues(alpha: 0.4) : AppColors.cardBorder.withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(2),
                                  bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(msg['name'] ?? 'Membro', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                  }),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.2))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                        ),
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Digite uma mensagem...',
                            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _sendMessage,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withValues(alpha: 0.2),
                        highlightColor: Colors.white.withValues(alpha: 0.1),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.send, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() {
    if (_myClanId == null || _currentUserUid == null) return;
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    
    ClanService().sendMessage(_myClanId!, _currentUserUid!, _myName ?? 'Eu', text);
    _chatCtrl.clear();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Widget _label(String t) => Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {bool isPassword = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPassword,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _clanPrimaryColor)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildClanMascot(int totalXp) {
    Color auraColor;
    if (totalXp >= 15000) {
      auraColor = AppColors.gold; 
    } else if (totalXp >= 8000) {
      auraColor = Colors.grey[300]!; 
    } else {
      auraColor = const Color(0xFFCD7F32); 
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.card,
        boxShadow: [
          BoxShadow(color: auraColor.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2),
        ],
        border: Border.all(color: auraColor, width: 2),
      ),
      child: Center(child: Icon(_clanIcon, color: auraColor, size: 28)),
    );
  }

  Widget _buildClanQuests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MISSÕES DA SEMANA', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 10),
        ..._mockQuests.map((q) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: q.isCompleted ? AppColors.gold.withValues(alpha: 0.5) : AppColors.cardBorder.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(q.title, style: TextStyle(color: q.isCompleted ? AppColors.gold : Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(q.rewardDescription, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: q.progressPercentage),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor: AppColors.inputBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(q.isCompleted ? AppColors.gold : AppColors.primary),
                            minHeight: 6,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${q.currentProgress}/${q.targetProgress}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }

  void _createClan() async {
    if (!_formKeyCreate.currentState!.validate()) return;
    if (_currentUserUid == null) return;
    
    try {
      final name = _nameCtrl.text.trim();
      final pwd = _passwordCtrl.text.trim();
      
      final clanId = await ClanService().createClan(
        name,
        'Novo clã EXS',
        _currentUserUid!,
        pwd.isEmpty,
        pwd.isEmpty ? null : pwd,
      );
      
      setState(() {
        _clanName = name;
        _myClanId = clanId;
        _clanCreated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clã "$_clanName" criado com sucesso!'), backgroundColor: AppColors.primary),
      );
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _joinClan() async {
    if (!_formKeyJoin.currentState!.validate()) return;
    if (_currentUserUid == null) return;
    
    // Na vida real a gente teria uma pesquisa de clã.
    // Pra testes, caso informe o CODIGO/ID que criaram na tela test.
    final clanId = _joinCodeCtrl.text.trim();
    final pwd = _joinPasswordCtrl.text.trim();
    
    try {
      await ClanService().joinClan(clanId, _currentUserUid!, pwd.isEmpty ? null : pwd);
      setState(() {
        _myClanId = clanId;
      });
      await _loadUserClan();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você entrou no clã!'), backgroundColor: AppColors.primary),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showEditClanDialog() {
    final editCtrl = TextEditingController(text: _clanName);
    Color tempColor = _clanPrimaryColor;
    IconData tempIcon = _clanIcon;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.primary)),
            title: const Text('Editar Clã', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 24),
                  const Text('Cor Principal', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AppColors.primary,
                      AppColors.gold,
                      Colors.redAccent,
                      Colors.blueAccent,
                      Colors.greenAccent,
                    ].map((c) => GestureDetector(
                      onTap: () => setDialogState(() => tempColor = c),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: Colors.white, width: tempColor == c ? 3 : 0)),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Ícone do Escudo', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icons.shield,
                      Icons.security,
                      Icons.bolt,
                      Icons.local_fire_department,
                      Icons.pets,
                    ].map((i) => GestureDetector(
                      onTap: () => setDialogState(() => tempIcon = i),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: tempIcon == i ? tempColor.withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                        child: Icon(i, color: tempIcon == i ? tempColor : AppColors.textMuted, size: 28),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _clanName = editCtrl.text.trim().isEmpty ? _clanName : editCtrl.text.trim();
                    _clanPrimaryColor = tempColor;
                    _clanIcon = tempIcon;
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('SALVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        }
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
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context, true); },
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onManage,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
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
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onManage,
                      customBorder: const CircleBorder(),
                      splashColor: AppColors.primary.withValues(alpha: 0.2),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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