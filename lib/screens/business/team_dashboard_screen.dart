import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

// ─────────────────────────────────────────────────────────────────
//  SPARK BUSINESS — Painel da equipe (PDF §5.6)
//
//  Lê a organização cujo ownerUid é o usuário atual e permite
//  convidar/remover membros. Métricas de progresso são lidas do campo
//  `members[].progressPercent` (preenchido pelo backend) — exibe 0 se
//  ainda não houver dado.
// ─────────────────────────────────────────────────────────────────

final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

/// Organização da qual o usuário atual é dono (primeira encontrada).
final myOrgProvider = StreamProvider.autoDispose<QueryDocumentSnapshot?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return _db
      .collection('organizations')
      .where('ownerUid', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first);
});

class TeamDashboardScreen extends ConsumerStatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  ConsumerState<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends ConsumerState<TeamDashboardScreen> {
  final _inviteCtrl = TextEditingController();

  @override
  void dispose() {
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite(DocumentReference orgRef, List members, int seats) async {
    final email = _inviteCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) return;
    if (members.length >= seats) {
      _snack(AppLocalizations.of(context)!.teamSeatsLimit(seats));
      return;
    }
    if (members.any((m) => (m['email'] as String?)?.toLowerCase() == email)) {
      _snack(AppLocalizations.of(context)!.teamEmailInvited);
      return;
    }
    await orgRef.update({
      'members': FieldValue.arrayUnion([
        {'email': email, 'status': 'invited', 'progressPercent': 0}
      ])
    });
    _inviteCtrl.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _remove(DocumentReference orgRef, Map member) async {
    await orgRef.update({
      'members': FieldValue.arrayRemove([member])
    });
  }

  void _snack(String m) => SparkSnack.info(context, m);

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(myOrgProvider);

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(AppLocalizations.of(context)!.teamDashboardTitle),
          ),
          body: SafeArea(
            top: false,
            child: orgAsync.when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text(AppLocalizations.of(context)!.genericErrorPrefix(e.toString()),
                      style: const TextStyle(color: AppColors.textMuted))),
              data: (doc) =>
                  doc == null ? _empty(context) : _dashboard(doc),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.teamNoTeam,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.push('/business-setup'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(AppLocalizations.of(context)!.teamCreateBusiness,
                    style: TextStyle(
                        color: AppColors.surfaceAlt, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final orgRef = doc.reference;
    final name = data['name'] as String? ?? AppLocalizations.of(context)!.teamMyTeam;
    final seats = (data['seats'] as num?)?.toInt() ?? 0;
    final members = (data['members'] as List?) ?? const [];
    final avg = members.isEmpty
        ? 0
        : (members
                    .map((m) => (m['progressPercent'] as num?)?.toDouble() ?? 0)
                    .reduce((a, b) => a + b) /
                members.length)
            .round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Row(
          children: [
            _stat(AppLocalizations.of(context)!.teamSeats, '${members.length}/$seats', Icons.event_seat),
            const SizedBox(width: 12),
            _stat(AppLocalizations.of(context)!.teamAvgProgress, '$avg%', Icons.trending_up),
          ],
        ),
        const SizedBox(height: 24),
        Text(AppLocalizations.of(context)!.teamInviteMember,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inviteCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'email@empresa.com.br',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.cardBorder.withValues(alpha: 0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.cardBorder.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _invite(orgRef, members, seats),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add, color: AppColors.surfaceAlt),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(AppLocalizations.of(context)!.teamMembers,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(AppLocalizations.of(context)!.teamNoMembers,
                style: TextStyle(color: AppColors.textMuted)),
          )
        else
          ...members.map((m) => _MemberTile(
                member: m as Map,
                onRemove: () => _remove(orgRef, m),
              )),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 8),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map member;
  final VoidCallback onRemove;
  const _MemberTile({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final email = member['email'] as String? ?? '—';
    final status = member['status'] as String? ?? 'active';
    final progress = (member['progressPercent'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(
                    status == 'invited'
                        ? AppLocalizations.of(context)!.teamInvitePending
                        : AppLocalizations.of(context)!.teamProgress(progress),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
