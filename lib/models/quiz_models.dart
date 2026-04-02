// ─────────────────────────────────────────────────────────────────
//  MODELOS DE QUIZ E LIÇÕES
// ─────────────────────────────────────────────────────────────────

/// Tipos de questão suportados pelo SPARK.
enum QuestionType { multipleChoice, trueFalse, fillInTheBlanks }

// ─────────────────────────────────────────────────────────────────
//  QUESTION BASE
// ─────────────────────────────────────────────────────────────────

/// Classe base abstrata para todos os tipos de questão.
abstract class Question {
  final String id;
  final String statement;
  final String explanation;
  final QuestionType type;

  const Question({
    required this.id,
    required this.statement,
    required this.explanation,
    required this.type,
  });
}

// ─────────────────────────────────────────────────────────────────
//  MÚLTIPLA ESCOLHA
// ─────────────────────────────────────────────────────────────────

class MultipleChoice extends Question {
  /// As opções disponíveis (geralmente 4).
  final List<String> options;

  /// Índice (0-based) da opção correta.
  final int correctIndex;

  const MultipleChoice({
    required super.id,
    required super.statement,
    required super.explanation,
    required this.options,
    required this.correctIndex,
  }) : super(type: QuestionType.multipleChoice);
}

// ─────────────────────────────────────────────────────────────────
//  VERDADEIRO OU FALSO
// ─────────────────────────────────────────────────────────────────

class TrueFalse extends Question {
  /// `true` = afirmação é Verdadeira. `false` = afirmação é Falsa.
  final bool isTrue;

  const TrueFalse({
    required super.id,
    required super.statement,
    required super.explanation,
    required this.isTrue,
  }) : super(type: QuestionType.trueFalse);
}

// ─────────────────────────────────────────────────────────────────
//  PREENCHER LACUNAS
// ─────────────────────────────────────────────────────────────────

/// Representa uma lacuna no enunciado.
class Blank {
  /// Posição da lacuna no texto base (ex: "A tensão no barramento _____ é medida por _____.").
  final int index;

  /// Resposta correta esperada (case-insensitive no domínio da correção).
  final String answer;

  const Blank({required this.index, required this.answer});
}

class FillInTheBlanks extends Question {
  /// Texto com placeholders marcados como "____".
  final String textWithBlanks;

  /// Lista de lacunas na ordem em que aparecem no texto.
  final List<Blank> blanks;

  const FillInTheBlanks({
    required super.id,
    required super.statement,
    required super.explanation,
    required this.textWithBlanks,
    required this.blanks,
  }) : super(type: QuestionType.fillInTheBlanks);
}

// ─────────────────────────────────────────────────────────────────
//  LESSON
// ─────────────────────────────────────────────────────────────────

/// Tipos de lição: conteúdo didático ou avaliação.
enum LessonType { lesson, evaluation }

/// Uma lição completa com enunciado didático e suas questões.
class Lesson {
  final String id;
  final String title;
  final String subtitle;
  final LessonType type;

  /// Texto de conteúdo didático exibido antes das questões (markdown suportado).
  final String content;

  /// Questões da lição (podem ser de tipos mistos).
  final List<Question> questions;

  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    this.type = LessonType.lesson,
    this.content = '',
    this.questions = const [],
  });

  bool get isEvaluation => type == LessonType.evaluation;
}
