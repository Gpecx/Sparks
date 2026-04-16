import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/fs.dart';
import '../models/user_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  String _calcTension(int xp) {
    if (xp < 5000) return 'BT';
    if (xp < 15000) return 'MT';
    if (xp < 30000) return 'AT';
    return 'EAT';
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _fs.collection(FS.users).doc(uid).get();
    if (doc.exists) return UserModel.fromFirestore(doc);
    return null;
  }

  Stream<UserModel> watchUser(String uid) {
    return _fs.collection(FS.users).doc(uid).snapshots().map((doc) => UserModel.fromFirestore(doc));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _fs.collection(FS.users).doc(uid).update(data);
  }

  Future<void> addXp(String uid, int amount) async {
    await _fs.runTransaction((tx) async {
      final ref = _fs.collection(FS.users).doc(uid);
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final currentXp = (doc.data()![FS.xp] as num).toInt();
      final newXp = currentXp + amount;
      
      tx.update(ref, {
        FS.xp: FieldValue.increment(amount),
        FS.weeklyXp: FieldValue.increment(amount),
        FS.monthlyXp: FieldValue.increment(amount),
        FS.tensionLevel: _calcTension(newXp),
      });
    });
  }

  Future<void> addSP(String uid, int amount) async {
    await _fs.collection(FS.users).doc(uid).update({
      FS.sparkPoints: FieldValue.increment(amount)
    });
  }

  Future<bool> spendSP(String uid, int amount) async {
    final ref = _fs.collection(FS.users).doc(uid);
    return await _fs.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return false;
      final currentSP = (doc.data()![FS.sparkPoints] as num).toInt();
      if (currentSP >= amount) {
        tx.update(ref, {FS.sparkPoints: FieldValue.increment(-amount)});
        return true;
      }
      return false;
    });
  }

  Future<bool> spendEnergy(String uid) async {
    final ref = _fs.collection(FS.users).doc(uid);
    return await _fs.runTransaction((tx) async {
       final doc = await tx.get(ref);
       if (!doc.exists) return false;
       final energy = (doc.data()![FS.energy] as num).toInt();
       if (energy <= 0) return false;
       
       tx.update(ref, {
         FS.energy: FieldValue.increment(-1),
         if (energy == 25) FS.energyLastRegen: FieldValue.serverTimestamp(),
       });
       return true;
    });
  }

  Future<void> regenEnergy(String uid) async {
    final ref = _fs.collection(FS.users).doc(uid);
    await _fs.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final energy = (doc.data()![FS.energy] as num).toInt();
      final lastRegen = (doc.data()![FS.energyLastRegen] as Timestamp).toDate().toUtc();
      
      if (energy >= 25) return;
      
      final now = DateTime.now().toUtc();
      final diff = now.difference(lastRegen).inMinutes;
      final gained = diff ~/ 5;
      
      if (gained > 0) {
        final newEnergy = (energy + gained).clamp(0, 25);
        final newRegen = lastRegen.add(Duration(minutes: gained * 5));
        
        tx.update(ref, {
          FS.energy: newEnergy,
          FS.energyLastRegen: newEnergy == 25 ? FieldValue.serverTimestamp() : Timestamp.fromDate(newRegen),
        });
      }
    });
  }

  Future<void> updateStreak(String uid) async {
    final ref = _fs.collection(FS.users).doc(uid);
    await _fs.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      
      final streak = (doc.data()![FS.streak] as num).toInt();
      final longest = (doc.data()![FS.longestStreak] as num).toInt();
      final lastLogin = (doc.data()![FS.lastLoginDate] as Timestamp).toDate().toUtc();
      
      final now = DateTime.now().toUtc();
      final today = DateTime(now.year, now.month, now.day);
      final last = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
      final diff = today.difference(last).inDays;
      
      if (diff == 1) {
        final newStreak = streak + 1;
        tx.update(ref, {
          FS.streak: FieldValue.increment(1),
          FS.longestStreak: newStreak > longest ? newStreak : longest,
          FS.lastLoginDate: FieldValue.serverTimestamp(),
        });
      } else if (diff > 1) {
        tx.update(ref, {
          FS.streak: 1,
          FS.lastLoginDate: FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(ref, {
          FS.lastLoginDate: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> addBadge(String uid, String badgeId) async {
    await _fs.collection(FS.users).doc(uid).update({
      FS.userBadges: FieldValue.arrayUnion([badgeId]),
    });
  }

  Future<void> saveQuizResult(String uid, Map<String, dynamic> result) async {
    await _fs.collection(FS.users).doc(uid).collection(FS.quizHistory).add(result);
  }
}
