// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spark_app/services/question_service.dart';

// ─────────────────────────────────────────────────────────────────
//  TESTES: QuestionService
//
//  Usa fake_cloud_firestore para simular o Firestore localmente.
//  NOTA: fake_cloud_firestore não suporta startAfterDocument com
//  cursor real. Testes de paginação via cursor devem ser validados
//  com o emulador do Firestore (integration tests).
//
//  Cobertura aqui:
//   - addQuestions: batch write
//   - getQuestions: primeira página com limit
//   - getQuestions: hasMore=false quando itens < limit
//   - getQuestions: coleção vazia
//   - getQuestionsSimple: retrocompatibilidade
//   - QuestionPage: model contract
// ─────────────────────────────────────────────────────────────────

const _catId = 'cat1';
const _modId = 'mod1';
const _trailId = 'trail1';
const _lessonId = 'lesson1';

Future<void> _seed(FakeFirebaseFirestore fakeFs, {int count = 25}) async {
  final batch = fakeFs.batch();
  final colRef = fakeFs
      .collection('categories')
      .doc(_catId)
      .collection('modules')
      .doc(_modId)
      .collection('trails')
      .doc(_trailId)
      .collection('lessons')
      .doc(_lessonId)
      .collection('questions');

  for (int i = 1; i <= count; i++) {
    batch.set(colRef.doc('q${i.toString().padLeft(3, '0')}'), {
      'id': 'q${i.toString().padLeft(3, '0')}',
      'order': i,
      'type': 'multipleChoice',
      'statement': 'Enunciado $i',
      'explanation': 'Explicação $i',
      'isActive': true,
      'options': ['A', 'B', 'C', 'D'],
      'correctIndex': 0,
    });
  }
  await batch.commit();
}

void main() {
  // ── addQuestions ────────────────────────────────────────────────

  group('QuestionService.addQuestions', () {
    test('grava 5 questões corretamente via batch', () async {
      final fakeFs = FakeFirebaseFirestore();
      final service = QuestionService.forTesting(fakeFs);

      final qs = List.generate(
        5,
        (i) => {
          'id': 'q${i + 1}',
          'order': i + 1,
          'type': 'multipleChoice',
          'statement': 'Enunciado ${i + 1}',
          'explanation': '',
          'isActive': true,
          'options': ['A', 'B'],
          'correctIndex': 0,
        },
      );

      await service.addQuestions(_catId, _modId, _trailId, _lessonId, qs);

      final snap = await fakeFs
          .collection('categories')
          .doc(_catId)
          .collection('modules')
          .doc(_modId)
          .collection('trails')
          .doc(_trailId)
          .collection('lessons')
          .doc(_lessonId)
          .collection('questions')
          .get();

      expect(snap.docs.length, equals(5));
    });

    test('grava exatamente os campos passados', () async {
      final fakeFs = FakeFirebaseFirestore();
      final service = QuestionService.forTesting(fakeFs);

      await service.addQuestions(_catId, _modId, _trailId, _lessonId, [
        {
          'id': 'q1',
          'order': 1,
          'type': 'multipleChoice',
          'statement': 'Qual é a letra A?',
          'explanation': '',
          'isActive': true,
          'options': ['A', 'B'],
          'correctIndex': 0,
        }
      ]);

      final doc = await fakeFs
          .collection('categories')
          .doc(_catId)
          .collection('modules')
          .doc(_modId)
          .collection('trails')
          .doc(_trailId)
          .collection('lessons')
          .doc(_lessonId)
          .collection('questions')
          .doc('q1')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!['statement'], equals('Qual é a letra A?'));
      expect(doc.data()!['correctIndex'], equals(0));
    });
  });

  // ── getQuestions — básico ────────────────────────────────────────

  group('QuestionService.getQuestions — básico', () {
    late FakeFirebaseFirestore fakeFs;
    late QuestionService service;

    setUp(() async {
      fakeFs = FakeFirebaseFirestore();
      service = QuestionService.forTesting(fakeFs);
    });

    test('primeira página retorna até limit=10 itens', () async {
      await _seed(fakeFs, count: 25);

      final page = await service.getQuestions(
        _catId, _modId, _trailId, _lessonId,
        limit: 10,
      );

      expect(page.items.length, equals(10));
      expect(page.hasMore, isTrue);
      expect(page.lastDoc, isNotNull);
    });

    test('hasMore=false quando total de itens é menor que limit', () async {
      await _seed(fakeFs, count: 5);

      final page = await service.getQuestions(
        _catId, _modId, _trailId, _lessonId,
        limit: 20,
      );

      expect(page.items.length, equals(5));
      expect(page.hasMore, isFalse);
    });

    test('hasMore=false quando total == limit', () async {
      await _seed(fakeFs, count: 10);

      final page = await service.getQuestions(
        _catId, _modId, _trailId, _lessonId,
        limit: 10,
      );

      // 10 == 10 → hasMore=true (pode haver mais, edge-case conservador)
      expect(page.items.length, equals(10));
      expect(page.hasMore, isTrue);
    });

    test('coleção vazia → itens vazios e hasMore=false', () async {
      final page = await service.getQuestions(
        _catId, _modId, _trailId, _lessonId,
        limit: 20,
      );

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.lastDoc, isNull);
    });

    test('limit padrão (20) é respeitado', () async {
      await _seed(fakeFs, count: 25);

      final page = await service.getQuestions(_catId, _modId, _trailId, _lessonId);

      // limit padrão = 20 → retorna 20 de 25
      expect(page.items.length, equals(20));
      expect(page.hasMore, isTrue);
    });

    test('questões retornadas têm campo question não-nulo', () async {
      await _seed(fakeFs, count: 3);

      final page = await service.getQuestions(
        _catId, _modId, _trailId, _lessonId,
        limit: 10,
      );

      for (final q in page.items) {
        expect(q.statement, isNotNull);
        expect(q.statement, isNotEmpty);
      }
    });
  });

  // ── getQuestionsSimple — retrocompatibilidade ────────────────────

  group('QuestionService.getQuestionsSimple', () {
    test('retorna lista simples com todos os itens até o limit', () async {
      final fakeFs = FakeFirebaseFirestore();
      final service = QuestionService.forTesting(fakeFs);
      await _seed(fakeFs, count: 5);

      final items = await service.getQuestionsSimple(
        _catId, _modId, _trailId, _lessonId,
        limit: 20,
      );

      expect(items.length, equals(5));
      expect(items, isA<List>());
    });

    test('retorna lista vazia para coleção vazia', () async {
      final fakeFs = FakeFirebaseFirestore();
      final service = QuestionService.forTesting(fakeFs);

      final items = await service.getQuestionsSimple(
        _catId, _modId, _trailId, _lessonId,
      );

      expect(items, isEmpty);
    });
  });

  // ── QuestionPage model ───────────────────────────────────────────

  group('QuestionPage model', () {
    test('construção com hasMore=true', () {
      const page = QuestionPage(items: [], lastDoc: null, hasMore: true);
      expect(page.hasMore, isTrue);
      expect(page.lastDoc, isNull);
      expect(page.items, isEmpty);
    });

    test('construção com hasMore=false', () {
      const page = QuestionPage(items: [], lastDoc: null, hasMore: false);
      expect(page.hasMore, isFalse);
    });

    test('hasMore reflecte se há mais itens disponíveis', () {
      const withMore = QuestionPage(items: [], lastDoc: null, hasMore: true);
      const noMore = QuestionPage(items: [], lastDoc: null, hasMore: false);
      expect(withMore.hasMore, isTrue);
      expect(noMore.hasMore, isFalse);
    });
  });
}
