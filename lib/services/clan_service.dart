import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/fs.dart';

class ClanService {
  static final ClanService _instance = ClanService._internal();
  factory ClanService() => _instance;
  ClanService._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  String _generateInviteCode() { 
     const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
     final rnd = Random();
     return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<String> createClan(String name, String desc, String creatorUid, bool isPublic, [String? password]) async {
    final inviteCode = _generateInviteCode();
    final clanRef = _fs.collection(FS.clans).doc();
    final userRef = _fs.collection(FS.users).doc(creatorUid);

    // Busca nome do criador antes de iniciar as escritas
    final userDoc = await userRef.get();
    final creatorName = userDoc.data()?[FS.name] ?? 'Admin';

    // 1. Cria o documento do clã primeiro (allow create: if isAuthenticated())
    await clanRef.set({
      FS.name: name,
      FS.description: desc,
      FS.createdBy: creatorUid,
      FS.isPublic: isPublic,
      'password': ?password,
      FS.inviteCode: inviteCode,
      FS.memberCount: 1,
      FS.maxMembers: 50,
      FS.totalXp: 0,
      FS.weeklyXp: 0,
      FS.rank: 0,
      FS.createdAt: FieldValue.serverTimestamp(),
    });

    // 2. Cria o membro-admin (request.auth.uid == memberUid passa)
    await clanRef.collection(FS.members).doc(creatorUid).set({
      FS.uid: creatorUid,
      FS.name: creatorName,
      FS.role: 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
      'weeklyContribution': 0,
      'xpContribution': 0,
    });

    // 3. Atualiza clanId do usuário (isSelf && !touchesSensitiveFields passa)
    await userRef.update({FS.clanId: clanRef.id});

    // 4. Inicializa missões de exemplo (agora o clã existe, createdBy == uid passa)
    final questBatch = _fs.batch();
    questBatch.set(clanRef.collection('quests').doc('q1'), {
      'title': 'Semana de Segurança',
      'currentProgress': 0,
      'targetProgress': 20,
      'rewardDescription': '+ 5.000 XP',
      'isCompleted': false,
    });
    questBatch.set(clanRef.collection('quests').doc('q2'), {
      'title': 'Mestres do Duelo',
      'currentProgress': 0,
      'targetProgress': 10,
      'rewardDescription': '+ 2.500 XP',
      'isCompleted': false,
    });
    await questBatch.commit();

    return clanRef.id;
  }

  Future<void> joinClan(String clanId, String uid, [String? password]) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);

    // 1. Valida o clã
    final clanDoc = await clanRef.get();
    if (!clanDoc.exists) throw Exception('Clã não encontrado');

    final data = clanDoc.data()!;
    final isPublic = data[FS.isPublic] as bool? ?? true;
    final storedPassword = data['password'] as String?;

    if (!isPublic && storedPassword != null && storedPassword.isNotEmpty) {
      if (password == null || password.isEmpty || password != storedPassword) {
        throw Exception('Senha incorreta');
      }
    }

    // 2. Busca nome do usuário
    final userRef = _fs.collection(FS.users).doc(uid);
    final userDoc = await userRef.get();
    final userName = (userDoc.data()?[FS.displayName] as String?) ??
        (userDoc.data()?[FS.name] as String?) ??
        'Membro';

    // 3. Adiciona membro à subcoleção
    final memberRef = clanRef.collection(FS.members).doc(uid);
    await memberRef.set({
      FS.uid: uid,
      FS.name: userName,
      FS.role: 'membro',
      'joinedAt': FieldValue.serverTimestamp(),
      'weeklyContribution': 0,
      'xpContribution': 0,
    });

    // 4. Incrementa contador de membros
    await clanRef.update({FS.memberCount: FieldValue.increment(1)});

    // 5. Atualiza o clanId do usuário
    await userRef.update({
      FS.clanId: clanId,
      FS.clanName: data[FS.name] as String? ?? '',
    });
  }

  Future<void> leaveClan(String clanId, String uid) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);
    
    await _fs.runTransaction((tx) async {
       final memberRef = clanRef.collection(FS.members).doc(uid);
       final memberDoc = await tx.get(memberRef);
       if (!memberDoc.exists) return;
       
       final isAdmin = memberDoc.data()?['role'] == 'admin';
       
       tx.delete(memberRef);
       tx.update(clanRef, {FS.memberCount: FieldValue.increment(-1)});
       
       final userRef = _fs.collection(FS.users).doc(uid);
       tx.update(userRef, {FS.clanId: FieldValue.delete()});

       if (isAdmin) {
         final membersSnap = await clanRef.collection(FS.members).limit(2).get();
         final remaining = membersSnap.docs.where((d) => d.id != uid).toList();
         
         if (remaining.isNotEmpty) {
            tx.update(remaining.first.reference, {FS.role: 'admin'});
         } else {
            tx.delete(clanRef);
         }
       }
    });
  }

  Future<void> deleteClan(String clanId) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Usuário não autenticado');

    // Verifica ownership antes de prosseguir
    final clanDoc = await clanRef.get();
    if (!clanDoc.exists) throw Exception('Clã não encontrado');
    
    final clanData = clanDoc.data()!;
    final isCreator = clanData[FS.createdBy] == uid;
    
    // Verifica se é admin
    final memberDoc = await clanRef.collection(FS.members).doc(uid).get();
    final isAdmin = memberDoc.exists && memberDoc.data()?[FS.role] == 'admin';
    
    if (!isCreator && !isAdmin) {
      throw Exception('Apenas o criador ou admin pode deletar o clã');
    }

    // 1. Remove o clanId de todos os membros
    final membersSnap = await clanRef.collection(FS.members).get();
    for (final doc in membersSnap.docs) {
      try {
        await _fs.collection(FS.users).doc(doc.id).update({FS.clanId: FieldValue.delete()});
      } catch (e) {
        debugPrint('Aviso: falha ao remover clanId do usuário ${doc.id}: $e');
      }
    }

    // 2. Deleta subcoleções (messages, quests, leagueProgress, weeklyMissions)
    final subcollections = ['messages', 'quests', 'leagueProgress', 'weeklyMissions'];
    for (final sub in subcollections) {
      try {
        final snap = await clanRef.collection(sub).get();
        for (final d in snap.docs) {
          await d.reference.delete();
        }
      } catch (_) {}
    }

    // 3. Deleta todos os membros EXCETO o chamador
    //    O membro do admin DEVE existir para que resource.data.createdBy == uid
    //    ou isAdmin passe ao deletar o doc do clã
    for (final doc in membersSnap.docs) {
      if (doc.id != uid) {
        try {
          await doc.reference.delete();
        } catch (e) {
          debugPrint('Aviso: falha ao deletar membro ${doc.id}: $e');
        }
      }
    }

    // 4. Deleta o documento do clã (regra: resource.data.createdBy == uid passa)
    await clanRef.delete();

    // 5. Por último, deleta o membro do admin (doc do clã já não existe,
    //    mas como é write no membro e request.auth.uid == memberUid, passa)
    try {
      await clanRef.collection(FS.members).doc(uid).delete();
    } catch (e) {
      debugPrint('Aviso: falha ao deletar membro admin: $e');
    }
  }

  Future<void> requestToJoin(String clanId, String uid) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);
    final userRef = _fs.collection(FS.users).doc(uid);
    
    final userDoc = await userRef.get();
    final userName = (userDoc.data()?[FS.displayName] as String?) ??
        (userDoc.data()?[FS.name] as String?) ??
        'Membro';

    await clanRef.collection('requests').doc(uid).set({
      'uid': uid,
      'name': userName,
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptJoinRequest(String clanId, String uid, String userName) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);
    final userRef = _fs.collection(FS.users).doc(uid);

    await clanRef.collection(FS.members).doc(uid).set({
      FS.uid: uid,
      FS.name: userName,
      FS.role: 'membro',
      'joinedAt': FieldValue.serverTimestamp(),
      'weeklyContribution': 0,
      'xpContribution': 0,
    });

    await clanRef.update({FS.memberCount: FieldValue.increment(1)});
    
    final clanDoc = await clanRef.get();
    await userRef.update({
      FS.clanId: clanId,
      FS.clanName: clanDoc.data()?[FS.name] as String? ?? '',
    });

    await clanRef.collection('requests').doc(uid).delete();
  }

  Future<void> rejectJoinRequest(String clanId, String uid) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);
    await clanRef.collection('requests').doc(uid).delete();
  }

  Future<void> updateMemberRole(String clanId, String uid, String newRole) async {
    final memberRef = _fs.collection(FS.clans).doc(clanId).collection(FS.members).doc(uid);
    await memberRef.update({FS.role: newRole});
  }

  Future<void> updateClanSettings(String clanId, String name, int colorValue, int iconCodePoint) async {
    final clanRef = _fs.collection(FS.clans).doc(clanId);
    await clanRef.update({
      FS.name: name,
      'primaryColor': colorValue,
      'iconCodePoint': iconCodePoint,
    });
  }

  Future<void> kickMember(String clanId, String uid) async {
    await leaveClan(clanId, uid);
  }

  Future<void> sendMessage(String clanId, String uid, String name, String text) async {
     final msgsCol = _fs.collection(FS.clans).doc(clanId).collection(FS.messages);
     final msgRef = msgsCol.doc();
     
     await msgRef.set({
       FS.uid: uid,
       FS.name: name,
       'text': text,
       'sentAt': FieldValue.serverTimestamp(),
     });

     // Limpeza assíncrona: Deletar mensagens com mais de 24 horas
     final yesterday = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
     msgsCol.where('sentAt', isLessThan: yesterday).get().then((snap) {
       if (snap.docs.isNotEmpty) {
         final batch = _fs.batch();
         for (var doc in snap.docs) {
           batch.delete(doc.reference);
         }
         batch.commit();
       }
     });
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String clanId) {
     final yesterday = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
     return _fs.collection(FS.clans).doc(clanId)
         .collection(FS.messages)
         .where('sentAt', isGreaterThanOrEqualTo: yesterday)
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

  // Calculates the global rank of a clan based on weeklyXp
  Future<int> getClanGlobalRank(String clanId) async {
    try {
      final querySnapshot = await _fs
          .collection(FS.clans)
          .orderBy(FS.weeklyXp, descending: true)
          .get();
      
      final docs = querySnapshot.docs;
      for (int i = 0; i < docs.length; i++) {
        if (docs[i].id == clanId) {
          return i + 1;
        }
      }
      return 0; // fallback if not found
    } catch (e) {
      debugPrint('Erro ao obter rank global do clã: $e');
      return 0;
    }
  }
}
