import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/fs.dart';

// ─────────────────────────────────────────────────────────────────
//  QUESTION SERVICE — Busca e gravação de questões no Firestore
//
//  Paginação:
//    - getQuestions aceita [lastDocument] para paginação via cursor.
//    - Use o campo [rawDoc] do último item retornado para buscar a
//      próxima página:
//
//      final page1 = await QuestionService().getQuestions(...);
//      final page2 = await QuestionService().getQuestions(
//        ..., lastDocument: page1.last.rawDoc);
// ─────────────────────────────────────────────────────────────────

class QuestionService {
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;
  QuestionService._internal() : _fs = FirebaseFirestore.instance;

  /// Construtor @visibleForTesting — permite injetar um Firestore fake nos testes.
  @visibleForTesting
  QuestionService.forTesting(FirebaseFirestore firestore) : _fs = firestore;

  final FirebaseFirestore _fs;

  // ─────────────────────────────────────────────────────────────────
  //  ESCRITA (seed / admin)
  // ─────────────────────────────────────────────────────────────────

  /// Grava uma lista de questões em batch direto no Firestore (usado no seed).
  /// Divide em chunks de 450 para respeitar o limite de 500 ops por batch.
  Future<void> addQuestions(
    String catId,
    String modId,
    String trailId,
    String lessonId,
    List<Map<String, dynamic>> qs,
  ) async {
    final colRef = _fs
        .collection(FS.categories)
        .doc(catId)
        .collection(FS.modules)
        .doc(modId)
        .collection(FS.trails)
        .doc(trailId)
        .collection(FS.lessons)
        .doc(lessonId)
        .collection(FS.questions);

    for (var i = 0; i < qs.length; i += 450) {
      final currentBatch = _fs.batch();
      final chunk = qs.skip(i).take(450);
      for (final q in chunk) {
        final docRef = colRef.doc(q['id'] as String);
        currentBatch.set(docRef, q);
      }
      await currentBatch.commit();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  LEITURA COM PAGINAÇÃO
  // ─────────────────────────────────────────────────────────────────

  /// Busca questões do Firestore com suporte a paginação via cursor.
  ///
  /// Parâmetros:
  ///  [catId], [modId], [lessonId] — caminho da lição
  ///  [limit]        — quantidade máxima de questões por página (padrão: 20)
  ///  [lastDocument] — cursor para a próxima página; obter de
  ///                   [QuestionPage.lastDoc] da página anterior.
  ///
  /// Retorna um [QuestionPage] com os itens e o cursor para a próxima página.
  Future<QuestionPage> getQuestions(
    String catId,
    String modId,
    String trailId,
    String lessonId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    var query = _fs
        .collection(FS.categories)
        .doc(catId)
        .collection(FS.modules)
        .doc(modId)
        .collection(FS.trails)
        .doc(trailId)
        .collection(FS.lessons)
        .doc(lessonId)
        .collection(FS.questions)
        .orderBy(FS.order)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    final items = snap.docs.map((d) => QuestionModel.fromFirestore(d)).toList();

    return QuestionPage(
      items: items,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == limit,
    );
  }

  /// Versão simples sem paginação — compatibilidade retroativa.
  /// Preferir [getQuestions] com paginação em fluxos de produção.
  Future<List<QuestionModel>> getQuestionsSimple(
    String catId,
    String modId,
    String trailId,
    String lessonId, {
    int limit = 20,
  }) async {
    final page = await getQuestions(catId, modId, trailId, lessonId, limit: limit);
    return page.items;
  }
}

// ─────────────────────────────────────────────────────────────────
//  QUESTION PAGE — Resultado paginado
// ─────────────────────────────────────────────────────────────────

class QuestionPage {
  /// Lista de questões desta página.
  final List<QuestionModel> items;

  /// Cursor para a próxima página. Null se não houver mais itens.
  final DocumentSnapshot? lastDoc;

  /// true se pode haver mais itens após esta página.
  final bool hasMore;

  const QuestionPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}
