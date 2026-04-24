import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:spark_app/models/user_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('UserModel Tests', () {
    test('fromFirestore parses valid data correctly', () async {
      // Usando fake_cloud_firestore se estiver configurado
      // ou apenas mockando os dados. Neste caso vamos testar via 
      // simulação de extração de dados do HashMap.

      final now = DateTime.now();
      final Map<String, dynamic> fakeData = {
        'displayName': 'Test User',
        'email': 'test@example.com',
        'role': 'Técnico',
        'sparkPoints': 100,
        'xp': 500,
        'level': 2,
        'tensionLevel': 'BT',
        'currentStreak': 5,
        'longestStreak': 10,
        'activeDays': 10,
        'studiedToday': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      // Como o Flutter Test roda sem inicializar o Firebase nativo, 
      // para testar model.fromFirestore precisamos de um FakeDocumentSnapshot.
      final fakeFirebase = FakeFirebaseFirestore();
      await fakeFirebase.collection('users').doc('user1').set(fakeData);
      
      final docSnapshot = await fakeFirebase.collection('users').doc('user1').get();

      final user = UserModel.fromFirestore(docSnapshot);

      expect(user.uid, 'user1');
      expect(user.displayName, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.role, 'Técnico');
      expect(user.sparkPoints, 100);
      expect(user.xp, 500);
      expect(user.level, 2);
      expect(user.currentStreak, 5);
      expect(user.studiedToday, true);
    });

    test('toFirestore returns correct Map', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user2',
        displayName: 'Test User 2',
        email: 'test2@test.com',
        role: 'Admin',
        sparkPoints: 0,
        xp: 0,
        level: 1,
        currentStreak: 0,
        longestStreak: 0,
        activeDays: 0,
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toFirestore();

      expect(map['displayName'], 'Test User 2');
      expect(map['email'], 'test2@test.com');
      expect(map['role'], 'Admin');
      expect(map['xp'], 0);
      expect(map.containsKey('updatedAt'), true);
    });

    test('copyWith updates fields correctly', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user3',
        displayName: 'Old Name',
        email: 'old@test.com',
        createdAt: now,
        updatedAt: now,
      );

      final updatedUser = user.copyWith(displayName: 'New Name', xp: 50);

      expect(updatedUser.uid, 'user3'); // should remain same
      expect(updatedUser.displayName, 'New Name'); // should change
      expect(updatedUser.email, 'old@test.com'); // should remain same
      expect(updatedUser.xp, 50); // should change
    });
  });
}
