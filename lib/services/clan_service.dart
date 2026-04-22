import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/fs.dart';

class ClanService {
  static final ClanService _instance = ClanService._internal();
  factory ClanService() => _instance;
  ClanService._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  String _generateInviteCode() { 
     const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
     final rnd = Random();
     return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<String> createClan(String name, String desc, String creatorUid, bool isPublic, [String? password]) async {
    final inviteCode = _generateInviteCode();
    final clanRef = _fs.collection(FS.clans).doc();
    final batch = _fs.batch();

    batch.set(clanRef, {
      FS.name: name,
      FS.description: desc,
      FS.createdBy: creatorUid,
      FS.isPublic: isPublic,
      if (password != null) 'password': password,
      FS.inviteCode: inviteCode,
      FS.memberCount: 1,
      FS.maxMembers: 50,
      FS.totalXp: 0,
      FS.weeklyXp: 0,
      FS.rank: 0,
      FS.createdAt: FieldValue.serverTimestamp(),
    });

    final memberRef = clanRef.collection(FS.members).doc(creatorUid);
    batch.set(memberRef, {
      FS.uid: creatorUid,
      FS.role: 'chefe',
      'joinedAt': FieldValue.serverTimestamp(),
      'weeklyContribution': 0,
      'xpContribution': 0,
    });

    final userRef = _fs.collection(FS.users).doc(creatorUid);
    batch.update(userRef, {FS.clanId: clanRef.id});

    await batch.commit();
    return clanRef.id;
  }

  Future<void> joinClan(String clanId, String uid, [String? password]) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);
    
    await _fs.runTransaction((tx) async {
      final doc = await tx.get(clanRef);
      if (!doc.exists) throw Exception('Clã não encontrado');
      
      final data = doc.data()!;
      if (!data[FS.isPublic] && data['password'] != password) throw Exception('Senha incorreta');

      final memberRef = clanRef.collection(FS.members).doc(uid);
      tx.set(memberRef, {
        FS.uid: uid,
        FS.role: 'membro',
        'joinedAt': FieldValue.serverTimestamp(),
        'weeklyContribution': 0,
        'xpContribution': 0,
      });

      tx.update(clanRef, {FS.memberCount: FieldValue.increment(1)});
      
      final userRef = _fs.collection(FS.users).doc(uid);
      tx.update(userRef, {FS.clanId: clanId});
    });
  }

  Future<void> leaveClan(String clanId, String uid) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);
    
    await _fs.runTransaction((tx) async {
       final memberRef = clanRef.collection(FS.members).doc(uid);
       final memberDoc = await tx.get(memberRef);
       if (!memberDoc.exists) return;
       
       final isChief = memberDoc.data()?['role'] == 'chefe';
       
       tx.delete(memberRef);
       tx.update(clanRef, {FS.memberCount: FieldValue.increment(-1)});
       
       final userRef = _fs.collection(FS.users).doc(uid);
       tx.update(userRef, {FS.clanId: FieldValue.delete()});

       if (isChief) {
         final membersSnap = await clanRef.collection(FS.members).limit(2).get();
         final remaining = membersSnap.docs.where((d) => d.id != uid).toList();
         
         if (remaining.isNotEmpty) {
            tx.update(remaining.first.reference, {FS.role: 'chefe'});
         } else {
            tx.delete(clanRef);
         }
       }
    });
  }

  Future<void> sendMessage(String clanId, String uid, String name, String text) async {
     final msgRef = _fs.collection(FS.clans).doc(clanId).collection(FS.messages).doc();
     await msgRef.set({
       FS.uid: uid,
       FS.name: name,
       'text': text,
       'sentAt': FieldValue.serverTimestamp(),
     });
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String clanId) {
     return _fs.collection(FS.clans).doc(clanId)
         .collection(FS.messages)
         .orderBy('sentAt', descending: true)
         .limit(50)
         .snapshots()
         .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> addXpToClan(String clanId, String uid, int amount) async {
     final batch = _fs.batch();
     final clanRef = _fs.collection(FS.clans).doc(clanId);
     
     batch.update(clanRef, {
       FS.totalXp: FieldValue.increment(amount),
       FS.weeklyXp: FieldValue.increment(amount),
     });

     final memberRef = clanRef.collection(FS.members).doc(uid);
     batch.update(memberRef, {
       'weeklyContribution': FieldValue.increment(amount),
       'xpContribution': FieldValue.increment(amount),
     });
     
     await batch.commit();
  }
}
