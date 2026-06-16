import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/i18n_utils.dart';

abstract class FS {
  // ── Root collections ──────────────────────────────────────────────────────
  static const String users = 'users';
  static const String categories = 'categories';
  static const String clans = 'clans';
  static const String rankings = 'rankings';
  static const String matches = 'matches';
  static const String matchmakingQueue = 'matchmaking_queue';
  static const String storeItems = 'store_items';
  static const String transactions = 'transactions';
  static const String voucherRedemptions = 'voucher_redemptions';
  static const String badges = 'badges';
  static const String activeEvents = 'active_events';
  static const String standardsMetadata = 'standards_metadata';

  // ── Sub-collections ───────────────────────────────────────────────────────
  static const String progress = 'progress';
  static const String quizHistory = 'quiz_history';
  static const String modules = 'modules';
  static const String trails = 'trails';
  static const String lessons = 'lessons';
  static const String ebooks = 'ebooks';
  static const String chapters = 'chapters';
  static const String ebookProgress = 'ebook_progress';
  static const String questions = 'questions';
  static const String members = 'members';
  static const String messages = 'messages';
  static const String covenants = 'covenants'; // subcoleção users/{uid}/covenants

  // ── Standards metadata fields ─────────────────────────────────────────────
  static const String clickCount = 'clickCount';
  static const String colorHex = 'colorHex';

  // ── Module fields ─────────────────────────────────────────────────────────
  static const String accessCount = 'accessCount';

  // ── Covenant selection fields ─────────────────────────────────────────────
  static const String isSelected = 'isSelected';
  static const String weekKey = 'weekKey';

  // ── User fields (esquema unificado UserModel) ─────────────────────────────
  static const String uid = 'uid';
  static const String displayName = 'displayName'; // padrão atual
  static const String email = 'email';
  static const String profession = 'profession';
  static const String photoUrl = 'photoUrl';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String xp = 'xp';
  static const String level = 'level';
  static const String tensionLevel = 'tensionLevel';
  static const String currentStreak = 'currentStreak';
  static const String longestStreak = 'longestStreak';
  static const String activeDays = 'activeDays';
  static const String studiedToday = 'studiedToday';
  static const String lastStudyDate = 'lastStudyDate';
  static const String weeklyXp = 'weeklyXp';
  static const String monthlyXp = 'monthlyXp';
  static const String unlockedBadgeIds = 'unlockedBadgeIds'; // padrão atual
  static const String role = 'role';
  static const String clanId = 'clanId';
  static const String clanName = 'clanName';
  static const String totalLessonsCompleted = 'totalLessonsCompleted';
  static const String totalCorrectAnswers = 'totalCorrectAnswers';
  static const String totalAnswers = 'totalAnswers';

  static const String title = 'title';
  static const String content = 'content';
  static const String lessonId = 'lessonId';

  // ── Aliases legados (dados antigos no Firestore — não usar em código novo) ─
  // ignore: constant_identifier_names
  static const String name = 'name';               // legado → use displayName
  // ignore: constant_identifier_names
  static const String streak = 'streak';            // legado → use currentStreak
  // ignore: constant_identifier_names
  static const String userBadges = 'badges';        // legado → use unlockedBadgeIds
  static const String energy = 'energy';
  static const String energyLastRegen = 'energyLastRegen';
  static const String lastLoginDate = 'lastLoginDate';
  static const String isPremium = 'isPremium';

  // ── Progress fields ───────────────────────────────────────────────────────
  static const String moduleId = 'moduleId';
  static const String categoryId = 'categoryId';
  static const String completedLessons = 'completedLessons';
  static const String progressPercent = 'progressPercent';
  static const String isCompleted = 'isCompleted';
  static const String startedAt = 'startedAt';
  static const String completedAt = 'completedAt';
  static const String lastAccessed = 'lastAccessed';
  static const String bestScore = 'bestScore';
  static const String attempts = 'attempts';

  // ── Question fields ───────────────────────────────────────────────────────
  static const String id = 'id';
  static const String order = 'order';
  static const String type = 'type';
  static const String statement = 'statement';
  static const String options = 'options';
  static const String correctIndex = 'correctIndex';
  static const String explanation = 'explanation';
  static const String difficulty = 'difficulty';
  static const String normReference = 'normReference';
  static const String imageUrl = 'imageUrl';
  static const String isActive = 'isActive';
  // TrueFalse
  static const String isTrue = 'isTrue';
  // FillInTheBlanks
  static const String textWithBlanks = 'textWithBlanks';
  static const String blanks = 'blanks';

  // ── Clan fields ───────────────────────────────────────────────────────────
  static const String description = 'description';
  static const String logoUrl = 'logoUrl';
  static const String createdBy = 'createdBy';
  static const String memberCount = 'memberCount';
  static const String maxMembers = 'maxMembers';
  static const String totalXp = 'totalXp';
  static const String isPublic = 'isPublic';
  static const String inviteCode = 'inviteCode';
  static const String rank = 'rank';

  // ── Match fields ──────────────────────────────────────────────────────────
  static const String player1Uid = 'player1Uid';
  static const String player2Uid = 'player2Uid';
  static const String status = 'status';
  static const String player1Scores = 'player1Scores';
  static const String player2Scores = 'player2Scores';
  static const String winnerId = 'winnerId';
  static const String finishedAt = 'finishedAt';
}

// ── QuestionModel ─────────────────────────────────────────────────────────────
// Modelo Firestore que suporta multipleChoice, trueFalse e fillInTheBlanks.

class QuestionModel {
  final String id;
  final int order;
  final String type;
  final String statement;
  final String explanation;
  final bool isActive;

  // multipleChoice
  final List<String>? options;
  final int? correctIndex;

  // trueFalse
  final bool? isTrue;

  // fillInTheBlanks
  final String? textWithBlanks;
  final List<Map<String, dynamic>>? blanks;

  const QuestionModel({
    required this.id,
    required this.order,
    required this.type,
    required this.statement,
    required this.explanation,
    required this.isActive,
    this.options,
    this.correctIndex,
    this.isTrue,
    this.textWithBlanks,
    this.blanks,
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc, {String? lang}) {
    final String l = lang ?? I18nUtils.currentLang;
    final d = doc.data() as Map<String, dynamic>;
    final type = d[FS.type] as String? ?? 'multipleChoice';

    // Para lacunas, o tradutor pode retornar uma lista de objects em "blanks".
    // Precisamos mesclar a resposta traduzida com o "index" original.
    List<Map<String, dynamic>>? parsedBlanks;
    if (type == 'fillInTheBlanks' && d[FS.blanks] != null) {
      final originalBlanks = List<Map<String, dynamic>>.from(d[FS.blanks] as List);
      final rawTranslations = I18nUtils.localizedRaw(d, FS.blanks, l);
      if (rawTranslations is List && rawTranslations.length == originalBlanks.length) {
        parsedBlanks = [];
        for (var i = 0; i < originalBlanks.length; i++) {
          final ob = originalBlanks[i];
          final tb = rawTranslations[i] as Map?;
          parsedBlanks.add({
            'index': ob['index'],
            'answer': tb?['answer'] ?? ob['answer'],
          });
        }
      } else {
        parsedBlanks = originalBlanks;
      }
    }

    return QuestionModel(
      id: doc.id,
      order: (d[FS.order] as num? ?? 0).toInt(),
      type: type,
      statement: I18nUtils.localized(d, FS.statement, l),
      explanation: I18nUtils.localized(d, FS.explanation, l),
      isActive: d[FS.isActive] as bool? ?? true,
      options: (type == 'multipleChoice' || type == 'fillInTheBlanks') && d[FS.options] != null
          ? I18nUtils.localizedList(d, FS.options, l)
          : null,
      correctIndex: (type == 'multipleChoice' || type == 'trueFalse' || type == 'true_false') && d[FS.correctIndex] != null
          ? (d[FS.correctIndex] as num).toInt()
          : null,
      isTrue: (type == 'trueFalse' || type == 'true_false')
          ? (d[FS.isTrue] as bool?)
              ?? (d[FS.correctIndex] != null
                  ? (d[FS.correctIndex] as num).toInt() == 0 
                  : null)
          : null,
      textWithBlanks: type == 'fillInTheBlanks'
          ? I18nUtils.localizedNullable(d, FS.textWithBlanks, l)
          : null,
      blanks: parsedBlanks,
    );
  }

  /// Converte para o formato Map interno usado pelo QuizScreen.
  ///
  /// [blankPool] é um conjunto opcional de termos reais da própria lição
  /// (respostas de outras lacunas) usado para enriquecer o banco de palavras
  /// do minigame preencher lacunas em runtime — garante distratores plausíveis
  /// mesmo quando o campo `options` não foi gravado na importação.
  Map<String, dynamic> toQuizMap(String moduleName, {Set<String>? blankPool}) {
    switch (type) {
      case 'multipleChoice':
        return {
          'type': 'multiple',
          'module': moduleName,
          'question': statement,
          'options': options ?? [],
          'correct': correctIndex ?? 0,
          'explanation': explanation,
        };
      case 'trueFalse':
      case 'true_false':
        // Derive from correctIndex when isTrue is null (admin saves correctIndex: 0/1)
        final resolvedAnswer = isTrue ?? (correctIndex != null ? correctIndex == 0 : false);
        return {
          'type': 'swipe',
          'module': moduleName,
          'question': 'Verdadeiro ou Falso?',
          'options': [statement],
          'answer': resolvedAnswer,
          'explanation': explanation,
        };
      case 'fillInTheBlanks':
        return _fillBlankQuizMap(moduleName, pool: blankPool);
      default:
        return {
          'type': 'multiple',
          'module': moduleName,
          'question': statement,
          'options': options ?? [],
          'correct': correctIndex ?? 0,
          'explanation': explanation,
        };
    }
  }

  /// Monta o formato "sentence_builder" (preencher lacunas com chips arrastáveis)
  /// usado pelo QuizScreen. O texto é quebrado nos marcadores de lacuna (`____`),
  /// as respostas vêm de [blanks] (na ordem de `index`) e o banco de palavras
  /// vem de [options] (gerados na importação) e/ou de [pool] (termos reais de
  /// outras lacunas da lição, montados em runtime).
  Map<String, dynamic> _fillBlankQuizMap(String moduleName, {Set<String>? pool}) {
    final text = (textWithBlanks != null && textWithBlanks!.trim().isNotEmpty)
        ? textWithBlanks!
        : statement;

    // Respostas ordenadas pela posição da lacuna no texto.
    final ordered = [...(blanks ?? const <Map<String, dynamic>>[])]
      ..sort((a, b) => ((a['index'] as num?)?.toInt() ?? 0)
          .compareTo((b['index'] as num?)?.toInt() ?? 0));
    final answers = ordered
        .map((b) => (b['answer'] as String?)?.trim() ?? '')
        .where((a) => a.isNotEmpty)
        .toList();

    // Sem lacunas utilizáveis: degrada para múltipla escolha simples.
    if (answers.isEmpty) {
      return {
        'type': 'multiple',
        'module': moduleName,
        'question': statement,
        'options': options ?? const <String>[],
        'correct': correctIndex ?? 0,
        'explanation': explanation,
      };
    }

    // Quebra o texto nos marcadores `____` (4+ underscores), preservando os
    // underscores internos de termos técnicos como kV_Base ou M_SP_NA_1.
    final segments = text.split(RegExp(r'_{4,}'));
    final fragments = <Map<String, dynamic>>[];
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].isNotEmpty) {
        fragments.add({'text': segments[i], 'isGap': false});
      }
      if (i < segments.length - 1 && i < answers.length) {
        fragments.add({'text': answers[i], 'isGap': true, 'id': 'slot$i'});
      }
    }

    final gapCount = fragments.where((f) => f['isGap'] == true).length;
    final usedAnswers = answers.take(gapCount).toList();

    // Banco de palavras: respostas corretas + distratores reais. Une os termos
    // gravados na importação (options) com o pool de runtime (outras lacunas da
    // lição), exclui as respostas, prioriza comprimento parecido (pra não
    // entregar a resposta pelo tamanho) e limita a respostas + 3 distratores.
    final distractors = <String>{
      ...(options ?? const <String>[]),
      ...(pool ?? const <String>{}),
    }.map((e) => e.trim()).where((e) => e.isNotEmpty && !usedAnswers.contains(e)).toList();
    final ref = usedAnswers.first.length;
    distractors.sort((a, b) => (a.length - ref).abs().compareTo((b.length - ref).abs()));
    final bank = <String>[...usedAnswers];
    for (final d in distractors) {
      if (bank.length >= usedAnswers.length + 3) break;
      bank.add(d);
    }
    bank.shuffle();

    return {
      'type': 'sentence_builder',
      'module': moduleName,
      'question': usedAnswers.length > 1
          ? 'Arraste os termos para preencher as lacunas:'
          : 'Arraste o termo para preencher a lacuna:',
      'fragments': fragments,
      'options': bank,
      'answer': usedAnswers,
      'explanation': explanation,
    };
  }

  Map<String, dynamic> toMap() => {
        FS.id: id,
        FS.order: order,
        FS.type: type,
        FS.statement: statement,
        FS.explanation: explanation,
        FS.isActive: isActive,
        if (options != null) FS.options: options,
        if (correctIndex != null) FS.correctIndex: correctIndex,
        if (isTrue != null) FS.isTrue: isTrue,
        if (textWithBlanks != null) FS.textWithBlanks: textWithBlanks,
        if (blanks != null) FS.blanks: blanks,
      };
}

// ── ClanModel ─────────────────────────────────────────────────────────────────

class ClanModel {
  final String id;
  final String name;
  final String description;
  final String logoUrl;
  final DateTime createdAt;
  final String createdBy;
  final int memberCount;
  final int maxMembers;
  final int totalXp;
  final int weeklyXp;
  final bool isPublic;
  final String inviteCode;
  final int rank;

  const ClanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.createdAt,
    required this.createdBy,
    required this.memberCount,
    required this.maxMembers,
    required this.totalXp,
    required this.weeklyXp,
    required this.isPublic,
    required this.inviteCode,
    required this.rank,
  });

  factory ClanModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClanModel(
      id: doc.id,
      name: d[FS.name] as String? ?? d[FS.displayName] as String? ?? 'Sem nome',
      description: d[FS.description] as String? ?? '',
      logoUrl: d[FS.logoUrl] as String? ?? '',
      createdAt: d[FS.createdAt] != null
          ? (d[FS.createdAt] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: d[FS.createdBy] as String? ?? '',
      memberCount: (d[FS.memberCount] as num?)?.toInt() ?? 0,
      maxMembers: (d[FS.maxMembers] as num?)?.toInt() ?? 50,
      totalXp: (d[FS.totalXp] as num?)?.toInt() ?? 0,
      weeklyXp: (d[FS.weeklyXp] as num?)?.toInt() ?? 0,
      isPublic: d[FS.isPublic] as bool? ?? true,
      inviteCode: d[FS.inviteCode] as String? ?? '',
      rank: (d[FS.rank] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        FS.id: id,
        FS.name: name,
        FS.description: description,
        FS.logoUrl: logoUrl,
        FS.createdAt: Timestamp.fromDate(createdAt),
        FS.createdBy: createdBy,
        FS.memberCount: memberCount,
        FS.maxMembers: maxMembers,
        FS.totalXp: totalXp,
        FS.weeklyXp: weeklyXp,
        FS.isPublic: isPublic,
        FS.inviteCode: inviteCode,
        FS.rank: rank,
      };
}

// ── MatchModel ────────────────────────────────────────────────────────────────

class MatchModel {
  final String id;
  final String player1Uid;
  final String player2Uid;
  final String status;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> player1Scores;
  final List<Map<String, dynamic>> player2Scores;
  final String? winnerId;
  final DateTime createdAt;
  final DateTime? finishedAt;

  const MatchModel({
    required this.id,
    required this.player1Uid,
    required this.player2Uid,
    required this.status,
    required this.questions,
    required this.player1Scores,
    required this.player2Scores,
    this.winnerId,
    required this.createdAt,
    this.finishedAt,
  });

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      player1Uid: d[FS.player1Uid] as String,
      player2Uid: d[FS.player2Uid] as String,
      status: d[FS.status] as String,
      questions: List<Map<String, dynamic>>.from(d[FS.questions] as List),
      player1Scores:
          List<Map<String, dynamic>>.from(d[FS.player1Scores] as List),
      player2Scores:
          List<Map<String, dynamic>>.from(d[FS.player2Scores] as List),
      winnerId: d[FS.winnerId] as String?,
      createdAt: (d[FS.createdAt] as Timestamp).toDate(),
      finishedAt: d[FS.finishedAt] != null
          ? (d[FS.finishedAt] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        FS.id: id,
        FS.player1Uid: player1Uid,
        FS.player2Uid: player2Uid,
        FS.status: status,
        FS.questions: questions,
        FS.player1Scores: player1Scores,
        FS.player2Scores: player2Scores,
        FS.winnerId: winnerId,
        FS.createdAt: Timestamp.fromDate(createdAt),
        FS.finishedAt: finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      };
}
