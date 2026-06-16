import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/services/clan_service.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/leaderboard_screen.dart';
enum ClanRole { admin, moderador, membro }

class ClanMember {
  final String uid;
  final String name;
  final String position;
  final int xp;
  final ClanRole role;
  final bool isUser;
  const ClanMember({required this.uid, required this.name, required this.position, required this.xp, required this.role, this.isUser = false});
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

class ClanLeague {
  final String name;
  final Color color;
  final int minXp;
  final IconData icon;
  const ClanLeague(this.name, this.color, this.minXp, this.icon);
}

final List<ClanLeague> _leagues = [
  const ClanLeague('Bronze', Colors.brown, 0, Icons.shield_outlined),
  const ClanLeague('Prata', Colors.grey, 5000, Icons.shield),
  const ClanLeague('Ouro', AppColors.gold, 15000, Icons.workspace_premium),
  const ClanLeague('Platina', Colors.cyanAccent, 30000, Icons.diamond),
  const ClanLeague('Diamante', Colors.blue, 60000, Icons.diamond),
  const ClanLeague('Mestre', Colors.purpleAccent, 100000, Icons.local_fire_department),
];

ClanLeague _getCurrentLeague(int xp) {
  for (int i = _leagues.length - 1; i >= 0; i--) {
    if (xp >= _leagues[i].minXp) return _leagues[i];
  }
  return _leagues.first;
}

ClanLeague? _getNextLeague(int xp) {
  for (int i = 0; i < _leagues.length; i++) {
    if (xp < _leagues[i].minXp) return _leagues[i];
  }
  return null;
}

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
  String _myRole = 'membro';
  String? _currentUserUid;
  String? _myName;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _joinPasswordCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();

  final _formKeyCreate = GlobalKey<FormState>();
  final _formKeyJoin = GlobalKey<FormState>();

  Color _clanPrimaryColor = AppColors.primary;
  IconData _clanIcon = Icons.shield;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    _myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Usuário';

    if (widget.isViewingActive) {
      _clanCreated = true;
    }
    
    _loadUserClan();
  }

  Future<void> _loadUserClan() async {
    if (_currentUserUid == null) return;
    try {
      final doc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('users').doc(_currentUserUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final clanId = data['clanId'];
        if (clanId != null) {
          final clanDoc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('clans').doc(clanId).get();
          if (mounted && clanDoc.exists) {
            final memberDoc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('clans').doc(clanId).collection('members').doc(_currentUserUid).get();
            String role = 'membro';
            if (memberDoc.exists) {
              role = memberDoc.data()?['role'] ?? 'membro';
            }
            setState(() {
              _myClanId = clanId;
              _myRole = role;
              _clanName = clanDoc.data()?['name'] ?? 'Clã Atual';
              
              if (clanDoc.data()?['primaryColor'] != null) {
                _clanPrimaryColor = Color(clanDoc.data()!['primaryColor']);
              }
              if (clanDoc.data()?['iconCodePoint'] != null) {
                _clanIcon = IconData(clanDoc.data()!['iconCodePoint'], fontFamily: 'MaterialIcons');
              }
              
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
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _passwordCtrl.dispose();
    _joinPasswordCtrl.dispose();
    _joinCodeCtrl.dispose();
    _chatCtrl.dispose();
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
                      ? AppLocalizations.of(context)!.createClanTitle
                      : AppLocalizations.of(context)!.joinClanTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.5),
            ),
            actions: _clanCreated && (_myRole == 'admin' || _myRole == 'moderador')
                ? [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: AppColors.card,
                      onSelected: (v) {
                        if (v == 'edit') _showEditClanDialog();
                        if (v == 'delete') _showDeleteDialog();
                      },
                      itemBuilder: (_) => [
                        if (_myRole == 'admin' || _myRole == 'moderador')
                          PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(context)!.editClanNamePassword, style: TextStyle(color: Colors.white))),
                        if (_myRole == 'admin')
                          PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context)!.deleteClan, style: TextStyle(color: Colors.redAccent))),
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
                Text(
                  AppLocalizations.of(context)!.createClanDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                _label(AppLocalizations.of(context)!.clanNameLabel),
                const SizedBox(height: 8),
                Form(
                  key: _formKeyCreate,
                  child: Column(
                    children: [
                      _inputField(
                        _nameCtrl, 
                        AppLocalizations.of(context)!.clanNameHint, 
                        Icons.shield_outlined,
                        maxLength: 50,
                        validator: (v) => (v == null || v.trim().length <= 3) ? AppLocalizations.of(context)!.clanNameValidator : null,
                      ),
                      const SizedBox(height: 16),
                      _label(AppLocalizations.of(context)!.clanDescriptionLabel),
                      const SizedBox(height: 8),
                      _inputField(
                        _descCtrl, 
                        AppLocalizations.of(context)!.clanDescriptionHint, 
                        Icons.description_outlined,
                        maxLength: 300,
                      ),
                      const SizedBox(height: 16),
                      _label(AppLocalizations.of(context)!.clanPasswordLabel),
                      const SizedBox(height: 8),
                      _inputField(
                        _passwordCtrl, 
                        AppLocalizations.of(context)!.clanPasswordHint, 
                        Icons.lock_outline, 
                        isPassword: true,
                        validator: (v) => (v == null || v.trim().length < 4) ? AppLocalizations.of(context)!.clanPasswordValidator : null,
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
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.createClanAdminNotice,
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
                    child: Text(AppLocalizations.of(context)!.createClanButton, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
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
                Text(
                  AppLocalizations.of(context)!.joinClanDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                _label(AppLocalizations.of(context)!.inviteCodeOptionalLabel),
                const SizedBox(height: 8),
                Form(
                  key: _formKeyJoin,
                  child: Column(
                    children: [
                      _inputField(_joinCodeCtrl, AppLocalizations.of(context)!.inviteCodeHint, Icons.confirmation_number_outlined),
                      const SizedBox(height: 16),
                      _label(AppLocalizations.of(context)!.clanPasswordLabel),
                      const SizedBox(height: 8),
                      _inputField(
                        _joinPasswordCtrl, 
                        AppLocalizations.of(context)!.clanPasswordJoinHint, 
                        Icons.lock_outline, 
                        isPassword: true,
                        validator: (v) => (_joinCodeCtrl.text.isEmpty && (v == null || v.isEmpty)) ? AppLocalizations.of(context)!.joinPasswordValidator : null,
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
                    child: Text(AppLocalizations.of(context)!.joinClanButton, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
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
    if (_myClanId == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('clans').doc(_myClanId).snapshots(),
      builder: (context, clanSnapshot) {
        if (!clanSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (!clanSnapshot.data!.exists) {
          return Center(child: Text(AppLocalizations.of(context)!.clanNotFound, style: TextStyle(color: Colors.white)));
        }

        final clanData = clanSnapshot.data!.data() as Map<String, dynamic>;
        final memberCount = clanData['memberCount'] ?? 1;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
              .collection('public_profiles')
              .where('clanId', isEqualTo: _myClanId)
              .snapshots(),
          builder: (context, usersSnapshot) {
            int totalXp = clanData['totalXp'] ?? 0;

            if (usersSnapshot.hasData) {
              int calculatedXp = 0;
              for (var doc in usersSnapshot.data!.docs) {
                final uData = doc.data() as Map<String, dynamic>;
                calculatedXp += (uData['xp'] as num? ?? 0).toInt();
              }

              if (calculatedXp != totalXp) {
                totalXp = calculatedXp;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
                      .collection('clans')
                      .doc(_myClanId)
                      .update({'totalXp': calculatedXp})
                      .catchError((e) => debugPrint('Erro ao atualizar totalXp do clã: $e'));
                });
              }
            }

            final currentLeague = _getCurrentLeague(totalXp);
            final nextLeague = _getNextLeague(totalXp);
            
            final double progress = nextLeague != null 
                ? ((totalXp - currentLeague.minXp) / (nextLeague.minXp - currentLeague.minXp)).clamp(0.0, 1.0)
                : 1.0;

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
                    _buildClanMascot(currentLeague),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_clanName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('$memberCount membros', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 12),
                          // Barra de Level do Clã
                          Row(
                            children: [
                              Text(currentLeague.name, style: TextStyle(color: currentLeague.color, fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFF1a1a1a),
                                    valueColor: AlwaysStoppedAnimation<Color>(currentLeague.color),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(nextLeague != null ? '${(totalXp/1000).toStringAsFixed(1)}k/${(nextLeague.minXp/1000).toStringAsFixed(1)}k XP' : AppLocalizations.of(context)!.maxLevel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showInviteDialog(clanData['inviteCode'] ?? 'SPARK'),
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
              FutureBuilder<int>(
                future: ClanService().getClanGlobalRank(_myClanId!),
                builder: (context, snapshot) {
                  final rank = snapshot.data ?? 0;
                  return _buildClanStats(currentLeague, rank);
                },
              ),
              const SizedBox(height: 20),

              // PEDIDOS DE ENTRADA
              if (_myRole == 'admin' || _myRole == 'moderador')
                _buildJoinRequests(),
              if (_myRole == 'admin' || _myRole == 'moderador')
                const SizedBox(height: 20),

              // MISSÕES DA SEMANA
              _buildClanQuests(),
              const SizedBox(height: 20),

              // Membros
              Text(AppLocalizations.of(context)!.membersListTitle, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('clans').doc(_myClanId).collection('members').orderBy('xpContribution', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final docs = snapshot.data!.docs;

                  final List<ClanMember> members = docs.map((doc) {
                    final mData = doc.data() as Map<String, dynamic>;
                    final roleStr = mData['role'] as String? ?? 'membro';
                    final roleEnum = roleStr == 'admin' ? ClanRole.admin : (roleStr == 'moderador' ? ClanRole.moderador : ClanRole.membro);
                    final uid = mData['uid'];
                    
                    // Buscar dados em tempo real da coleção /users
                    String realName = mData['name'] ?? 'Membro';
                    int realXp = mData['xpContribution'] ?? 0;
                    
                    if (usersSnapshot.hasData) {
                      for (var uDoc in usersSnapshot.data!.docs) {
                        if (uDoc.id == uid) {
                          final uData = uDoc.data() as Map<String, dynamic>;
                          realName = uData['name'] ?? uData['displayName'] ?? realName;
                          realXp = (uData['xp'] as num? ?? 0).toInt();
                          
                          // Sincroniza silenciosamente no banco do clã se divergir, apenas para o próprio usuário conectado
                          if (uid == _currentUserUid && (realXp != (mData['xpContribution'] ?? 0) || realName != mData['name'])) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
                                  .collection('clans')
                                  .doc(_myClanId)
                                  .collection('members')
                                  .doc(uid)
                                  .update({
                                    'xpContribution': realXp,
                                    'name': realName,
                                  })
                                  .catchError((e) => debugPrint('Erro ao sincronizar dados do membro: $e'));
                            });
                          }
                          break;
                        }
                      }
                    }
                    
                    return ClanMember(
                      uid: uid,
                      name: uid == _currentUserUid ? 'Eu' : realName, 
                      position: roleStr.toUpperCase(), 
                      xp: realXp, 
                      role: roleEnum,
                      isUser: uid == _currentUserUid,
                    );
                  }).toList();

                  // Ordena os membros em memória para garantir consistência visual em tempo real
                  members.sort((a, b) => b.xp.compareTo(a.xp));

                  return Column(
                    children: members.asMap().entries.map((entry) {
                      final i = entry.key;
                      final member = entry.value;
                      return _MemberTile(member: member, rank: i + 1, onManage: () => _showManageDialog(member));
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
      },
    );
  }
);
}

  Widget _buildClanStats(ClanLeague league, int rank) {
    return Row(
      children: [
        Expanded(
          child: _statCard(AppLocalizations.of(context)!.currentLeague, league.name, league.icon, league.color, onTap: _showLeagueTreeDialog),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(AppLocalizations.of(context)!.globalRank, rank > 0 ? '#$rank' : '-', Icons.public, _clanPrimaryColor, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen()));
          }),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
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
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
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
        Text(AppLocalizations.of(context)!.clanChatTitle, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
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
                            Text(AppLocalizations.of(context)!.chatSilent, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(AppLocalizations.of(context)!.beFirstToInteract, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                                  Text(msg['text'] ?? '', style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
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
                                      child: Text(msg['name'] ?? 'Membro', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
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
                          maxLength: 500,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.typeAMessage,
                            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            border: InputBorder.none,
                            counterText: '',
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

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {bool isPassword = false, String? Function(String?)? validator, int? maxLength}) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPassword,
      validator: validator,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
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

  Widget _buildClanMascot(ClanLeague league) {
    Color auraColor = league.color; // A aura ao redor reflete a liga (Ouro, Platina, etc)
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.inputBackground,
        boxShadow: [
          BoxShadow(color: auraColor.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 2),
        ],
        border: Border.all(color: _clanPrimaryColor, width: 2),
      ),
      child: Center(child: Icon(_clanIcon, color: _clanPrimaryColor, size: 28)),
    );
  }

  Widget _buildClanQuests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.weeklyQuestsTitle, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('clans').doc(_myClanId).collection('quests').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final quests = snapshot.data!.docs;
            if (quests.isEmpty) return Text(AppLocalizations.of(context)!.noActiveQuests, style: TextStyle(color: AppColors.textMuted));
            
            return Column(
              children: quests.map((q) {
                final data = q.data() as Map<String, dynamic>;
                final title = data['title'] ?? '';
                final currentProgress = data['currentProgress'] ?? 0;
                final targetProgress = data['targetProgress'] ?? 1;
                final rewardDescription = data['rewardDescription'] ?? '';
                final isCompleted = currentProgress >= targetProgress;
                final progressPercentage = (currentProgress / targetProgress).clamp(0.0, 1.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCompleted ? AppColors.gold.withValues(alpha: 0.5) : AppColors.cardBorder.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isCompleted ? AppColors.gold : Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Text(rewardDescription, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: progressPercentage),
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: AppColors.inputBackground,
                                    valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? AppColors.gold : AppColors.primary),
                                    minHeight: 6,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$currentProgress/$targetProgress', style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }
        ),
      ],
    );
  }

  void _createClan() async {
    if (!_formKeyCreate.currentState!.validate()) return;
    if (_currentUserUid == null) return;

    try {
      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim().isEmpty ? 'Novo clã EXS' : _descCtrl.text.trim();
      final pwd = _passwordCtrl.text.trim();
      
      final clanId = await ClanService().createClan(
        name,
        desc,
        _currentUserUid!,
        pwd.isEmpty,
        pwd.isEmpty ? null : pwd,
      );
      
      if (!mounted) return;
      setState(() {
        _clanName = name;
        _myClanId = clanId;
        _myRole = 'admin';
        _clanCreated = true;
      });
      SparkSnack.success(context, 'Clã "$_clanName" criado com sucesso!');
    } catch(e) {
      if (!mounted) return;
      SparkSnack.error(context, 'Erro ao criar: $e');
    }
  }

  void _joinClan() async {
    if (!_formKeyJoin.currentState!.validate()) return;
    if (_currentUserUid == null) return;

    final input = _joinCodeCtrl.text.trim();
    final pwd   = _joinPasswordCtrl.text.trim();

    try {
      // Tenta encontrar o clã por inviteCode primeiro, depois por ID direto
      final fs = FirebaseFirestore.instanceFor(
          app: Firebase.app(), databaseId: 'default');

      String resolvedClanId = input;
      bool usedCode = false;

      // Busca por código de convite (6 letras maiúsculas)
      final byCode = await fs
          .collection(FS.clans)
          .where(FS.inviteCode, isEqualTo: input.toUpperCase())
          .limit(1)
          .get();

      if (byCode.docs.isNotEmpty) {
        resolvedClanId = byCode.docs.first.id;
        usedCode = true;
      }

      if (usedCode) {
        await ClanService().requestToJoin(resolvedClanId, _currentUserUid!);
        if (!mounted) return;
        SparkSnack.success(context, AppLocalizations.of(context)!.joinRequestSent);
        return; // não muda o estado pra "já no clã"
      } else {
        await ClanService().joinClan(
            resolvedClanId, _currentUserUid!, pwd.isEmpty ? null : pwd);
      }

      if (!mounted) return;
      setState(() => _myClanId = resolvedClanId);
      await _loadUserClan();

      if (!mounted) return;
      SparkSnack.success(context, AppLocalizations.of(context)!.joinedClanSuccess);
    } catch (e) {
      if (!mounted) return;
      SparkSnack.error(context, 'Erro ao entrar: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _showEditClanDialog() {
    final editCtrl = TextEditingController(text: _clanName);
    Color tempColor = _clanPrimaryColor;
    IconData tempIcon = _clanIcon;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: tempColor.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview do Escudo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.inputBackground,
                        border: Border.all(color: tempColor, width: 3),
                        boxShadow: [
                          BoxShadow(color: tempColor.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2),
                        ],
                      ),
                      child: Center(
                        child: Icon(tempIcon, color: tempColor, size: 40),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(AppLocalizations.of(context)!.editClanTitle, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 24),
                    
                    // Input Name
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text('NOME DO CLÃ', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editCtrl,
                      maxLength: 50,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.newClanNameHint,
                        counterText: '',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tempColor)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Colors
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(AppLocalizations.of(context)!.mainColorLabel, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        AppColors.primary,
                        AppColors.gold,
                        Colors.redAccent,
                        Colors.blueAccent,
                        Colors.greenAccent,
                        Colors.purpleAccent,
                        Colors.orangeAccent,
                        Colors.tealAccent,
                      ].map((c) => GestureDetector(
                        onTap: () => setDialogState(() => tempColor = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, 
                            color: c, 
                            border: Border.all(color: Colors.white, width: tempColor == c ? 3 : 0),
                            boxShadow: tempColor == c ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)] : [],
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                    
                    // Icons
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(AppLocalizations.of(context)!.clanIconLabel, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        Icons.shield,
                        Icons.security,
                        Icons.bolt,
                        Icons.local_fire_department,
                        Icons.pets,
                        Icons.star,
                        Icons.flash_on,
                        Icons.eco,
                        Icons.anchor,
                        Icons.sports_esports,
                        Icons.verified_user,
                        Icons.diamond,
                      ].map((i) => GestureDetector(
                        onTap: () => setDialogState(() => tempIcon = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tempIcon == i ? tempColor.withValues(alpha: 0.15) : AppColors.inputBackground, 
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tempIcon == i ? tempColor.withValues(alpha: 0.5) : AppColors.cardBorder.withValues(alpha: 0.3)),
                          ),
                          child: Icon(i, color: tempIcon == i ? tempColor : AppColors.textMuted, size: 28),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 32),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isLoading ? null : () => Navigator.pop(ctx), 
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(AppLocalizations.of(context)!.cancelButton, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () async {
                              final newName = editCtrl.text.trim().isEmpty ? _clanName : editCtrl.text.trim();
                              setDialogState(() => isLoading = true);
                              try {
                                await ClanService().updateClanSettings(_myClanId!, newName, tempColor.value, tempIcon.codePoint);
                                if (mounted) {
                                  setState(() {
                                    _clanName = newName;
                                    _clanPrimaryColor = tempColor;
                                    _clanIcon = tempIcon;
                                  });
                                  Navigator.pop(ctx);
                                  SparkSnack.success(context, AppLocalizations.of(context)!.clanUpdatedSuccess);
                                }
                              } catch (e) {
                                if (mounted) {
                                  setDialogState(() => isLoading = false);
                                  SparkSnack.error(context, 'Erro ao atualizar clã: $e');
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tempColor, 
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(AppLocalizations.of(context)!.saveButton, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
        title: Text(AppLocalizations.of(context)!.deleteClanDialogTitle, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(AppLocalizations.of(context)!.deleteClanWarning, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.cancelButton, style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ClanService().deleteClan(_myClanId!);
                if (mounted) {
                  setState(() {
                    _myClanId = null;
                    _clanCreated = false;
                  });
                  SparkSnack.success(context, AppLocalizations.of(context)!.clanDeletedSuccess);
                }
              } catch (e) {
                if (mounted) {
                  SparkSnack.error(context, 'Erro ao deletar: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(AppLocalizations.of(context)!.deleteClanButton, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLeagueTreeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.primary)),
        title: Text(AppLocalizations.of(context)!.clanLeaguesTitle, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _leagues.map((l) => ListTile(
              leading: Icon(l.icon, color: l.color),
              title: Text(l.name, style: TextStyle(color: l.color, fontWeight: FontWeight.w700)),
              trailing: Text('${l.minXp} XP', style: const TextStyle(color: AppColors.textMuted)),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.closeButton, style: TextStyle(color: AppColors.textMuted))),
        ],
      ),
    );
  }

  void _showInviteDialog(String inviteCode) {
    bool copied = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.group_add_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.inviteToClanTitle,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text(AppLocalizations.of(context)!.shareCodeSubtitle,
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 20),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.inviteCodeInfo,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Código
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: inviteCode));
                          setDialogState(() => copied = true);
                          Future.delayed(const Duration(seconds: 2),
                              () => setDialogState(() => copied = false));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: copied
                                ? AppColors.primary.withValues(alpha: 0.18)
                                : AppColors.inputBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: copied
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                inviteCode,
                                style: TextStyle(
                                  color: copied
                                      ? AppColors.primary
                                      : Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 8,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                copied
                                    ? Icons.check_circle_rounded
                                    : Icons.copy_rounded,
                                color: copied
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: copied
                            ? Text(
                                AppLocalizations.of(context)!.codeCopied,
                                key: ValueKey('copied'),
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              )
                            : Text(
                                AppLocalizations.of(context)!.tapToCopy,
                                key: ValueKey('hint'),
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12),
                              ),
                      ),

                      const SizedBox(height: 24),

                      // Botões
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.cardBorder),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.closeButton,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: inviteCode));
                                setDialogState(() => copied = true);
                                if (ctx.mounted) {
                                  SparkSnack.success(ctx, AppLocalizations.of(context)!.codeCopied);
                                }
                              },
                              icon: Icon(
                                copied
                                    ? Icons.check_rounded
                                    : Icons.copy_rounded,
                                size: 16,
                              ),
                              label: Text(
                                copied ? AppLocalizations.of(context)!.copiedButton : AppLocalizations.of(context)!.copyCodeButton,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.joinRequestsTitle, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('clans').doc(_myClanId).collection('requests').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(AppLocalizations.of(context)!.noPendingRequests, style: TextStyle(color: AppColors.textMuted, fontSize: 13));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text(AppLocalizations.of(context)!.noPendingRequests, style: TextStyle(color: AppColors.textMuted, fontSize: 13));
            }
            final requests = snapshot.data!.docs;
            return Column(
              children: requests.map((req) {
                final data = req.data() as Map<String, dynamic>;
                final uid = req.id;
                final name = data['name'] ?? AppLocalizations.of(context)!.unknownMember;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_alt_1, color: AppColors.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: AppColors.primary),
                        onPressed: () async {
                          await ClanService().acceptJoinRequest(_myClanId!, uid, name);
                          if (!mounted) return;
                          SparkSnack.success(context, AppLocalizations.of(context)!.acceptJoinRequestSuccess);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: AppColors.error),
                        onPressed: () async {
                          await ClanService().rejectJoinRequest(_myClanId!, uid);
                          if (!mounted) return;
                          SparkSnack.error(context, AppLocalizations.of(context)!.rejectJoinRequestSuccess);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showManageDialog(ClanMember member) {
    if (member.isUser) return; // Não pode gerenciar a si mesmo
    if (_myRole == 'membro') {
      SparkSnack.error(context, 'Membros não têm permissão para gerenciar outros.');
      return;
    }
    if (_myRole == 'moderador' && (member.role == ClanRole.admin || member.role == ClanRole.moderador)) {
      SparkSnack.error(context, 'Moderadores não podem gerenciar outros Moderadores ou Admins.');
      return;
    }

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
            if (_myRole == 'admin' && member.role != ClanRole.admin)
              _actionTile(ctx, Icons.arrow_upward, member.role == ClanRole.membro ? 'Promover a Moderador' : 'Promover a Admin', AppColors.primary, () async {
                final newRole = member.role == ClanRole.membro ? 'moderador' : 'admin';
                await ClanService().updateMemberRole(_myClanId!, member.uid, newRole);
              }),
            if (_myRole == 'admin' && member.role == ClanRole.moderador)
              _actionTile(ctx, Icons.arrow_downward, 'Rebaixar a Membro', AppColors.error, () async {
                await ClanService().updateMemberRole(_myClanId!, member.uid, 'membro');
              }),
            _actionTile(ctx, Icons.person_remove_outlined, 'Expulsar do Clã', AppColors.error, () async {
              await ClanService().kickMember(_myClanId!, member.uid);
            }),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.cancelButton, style: TextStyle(color: AppColors.textMuted))),
        ],
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
        SparkSnack.success(context, '$label executado!');
      },
    );
  }

  String _roleName(ClanRole role) {
    switch (role) {
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
      case ClanRole.admin:
        roleColor = AppColors.gold; roleIcon = Icons.workspace_premium; break;
      case ClanRole.moderador:
        roleColor = AppColors.accent; roleIcon = Icons.shield; break;
      default:
        roleColor = AppColors.textMuted; roleIcon = Icons.person; break;
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
          .collection('public_profiles')
          .doc(member.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int displayXp = member.xp;
        int displayLevel = (member.xp ~/ 500) + 1;
        String displayName = member.name;
        String? photoUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final uData = snapshot.data!.data() as Map<String, dynamic>;
          displayXp = uData['xp'] ?? member.xp;
          displayLevel = uData['level'] ?? ((displayXp ~/ 500) + 1);
          displayName = uData['displayName'] ?? member.name;
          photoUrl = uData['photoUrl'];
        }

        // Calcula a porcentagem do nível atual
        // Cada nível precisa de 500 XP.
        final int xpInCurrentLevel = displayXp % 500;
        final double progress = xpInCurrentLevel / 500.0;

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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        color: roleColor.withValues(alpha: 0.15), 
                        border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                        image: photoUrl != null && photoUrl.isNotEmpty
                            ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Icon(Icons.person, color: roleColor, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
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
                              Flexible(
                                child: Text('· $displayXp XP', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: const Color(0xFF1a1a1a),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      member.isUser ? AppColors.primary : AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '$xpInCurrentLevel/500 XP (Nv. $displayLevel)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
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
      },
    );
  }

  String _roleLabelOf(ClanRole role) {
    switch (role) {
      case ClanRole.admin: return 'Admin';
      case ClanRole.moderador: return 'Moderador';
      default: return 'Membro';
    }
  }
}