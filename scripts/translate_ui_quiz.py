import json

def add_keys(keys_pt, keys_en, keys_es, keys_pt_meta=None):
    files = {
        'pt': 'lib/l10n/app_pt.arb',
        'en': 'lib/l10n/app_en.arb',
        'es': 'lib/l10n/app_es.arb'
    }
    
    with open(files['pt'], 'r', encoding='utf-8') as f: data_pt = json.load(f)
    with open(files['en'], 'r', encoding='utf-8') as f: data_en = json.load(f)
    with open(files['es'], 'r', encoding='utf-8') as f: data_es = json.load(f)

    for k, v in keys_pt.items():
        if k not in data_pt:
            data_pt[k] = v
            data_en[k] = keys_en.get(k, v)
            data_es[k] = keys_es.get(k, v)

    if keys_pt_meta:
        for k, v in keys_pt_meta.items():
            if k not in data_pt:
                data_pt[k] = v

    with open(files['pt'], 'w', encoding='utf-8') as f: json.dump(data_pt, f, indent=2, ensure_ascii=False)
    with open(files['en'], 'w', encoding='utf-8') as f: json.dump(data_en, f, indent=2, ensure_ascii=False)
    with open(files['es'], 'w', encoding='utf-8') as f: json.dump(data_es, f, indent=2, ensure_ascii=False)

def replace_in_file(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    import_stmt = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';"
    if import_stmt not in content:
        content = content.replace("import 'package:flutter/material.dart';", f"import 'package:flutter/material.dart';\n{import_stmt}")

    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

keys_pt = {
    "epicStreakBonus": "STREAK ÉPICO! +100 XP Bônus!",
    "streakBonusEnergy": "Acerto em sequência! +{bonus} energia bônus!",
    "successMessage": "Parabéns! Você alcançou {pct}% de acertos e ganhou {xpEarned} XP!",
    "evaluationPassed": "Avaliação Aprovada!",
    "lessonCompleted": "Lição concluída!",
    "insufficientPerformance": "Desempenho Insuficiente",
    "performanceLow": "Você obteve {score}%. É necessário no mínimo {required} para avançar. Revise o material e tente novamente.",
    "continueButton": "CONTINUAR",
    "redoButton": "REFAZER",
    "exitButton": "Sair",
    "batteryDepleted": "Bateria Esgotada!",
    "batteryDepletedDescription": "Você gastou toda a sua energia. Aguarde a recarga automática (5 min por unidade) ou assine um plano para ter bateria infinita ∞.",
    "viewPlansInfiniteBattery": "VER PLANOS COM BATERIA ∞",
    "exitQuiz": "Sair do Quiz",
    "skipButton": "Pular ✕",
    "powerplayTitle": "POWERPLAY",
    "congratsModule": "Parabens pelo modulo!",
    "tryPremiumVideosFree": "Continue aprendendo com vídeos técnicos exclusivos. Experimente grátis por 7 dias!",
    "tryFree7Days": "TESTE GRÁTIS POR 7 DIAS",
    "areYouSure": "Tem certeza?",
    "loseProgressWarning": "Você vai perder todo seu progresso na lição se sair.",
    "cancelUpper": "CANCELAR",
    "exitUpper": "SAIR",
    "noQuestionsRegistered": "Nenhuma questão cadastrada",
    "noQuestionsAdminContact": "Esta lição ainda não possui questões cadastradas no sistema. Por favor, entre em contato com o administrador.",
    "backButton": "VOLTAR",
    "loadingQuestions": "Carregando questões...",
    "questionProgress": "Pergunta {current} de {total}",
    "verifyButton": "VERIFICAR",
    "excellentFeedback": "Excelente!",
    "payAttentionFeedback": "Atenção ao detalhe!",
    "finishButton": "FINALIZAR",
    "falseUpper": "FALSO",
    "trueUpper": "VERDADEIRO",
    "noStatement": "Sem enunciado"
}

keys_pt_meta = {
    "@streakBonusEnergy": { "placeholders": { "bonus": { "type": "int" } } },
    "@successMessage": { "placeholders": { "pct": { "type": "int" }, "xpEarned": { "type": "int" } } },
    "@performanceLow": { "placeholders": { "score": { "type": "int" }, "required": { "type": "String" } } },
    "@questionProgress": { "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } } }
}

keys_en = {
    "epicStreakBonus": "EPIC STREAK! +100 Bonus XP!",
    "streakBonusEnergy": "Sequential hit! +{bonus} bonus energy!",
    "successMessage": "Congratulations! You achieved {pct}% accuracy and earned {xpEarned} XP!",
    "evaluationPassed": "Evaluation Passed!",
    "lessonCompleted": "Lesson completed!",
    "insufficientPerformance": "Insufficient Performance",
    "performanceLow": "You got {score}%. A minimum of {required} is required to advance. Review the material and try again.",
    "continueButton": "CONTINUE",
    "redoButton": "REDO",
    "exitButton": "Exit",
    "batteryDepleted": "Battery Depleted!",
    "batteryDepletedDescription": "You have spent all your energy. Wait for automatic recharge (5 min per unit) or subscribe to a plan to have infinite battery ∞.",
    "viewPlansInfiniteBattery": "VIEW PLANS WITH ∞ BATTERY",
    "exitQuiz": "Exit Quiz",
    "skipButton": "Skip ✕",
    "powerplayTitle": "POWERPLAY",
    "congratsModule": "Congratulations on the module!",
    "tryPremiumVideosFree": "Continue learning with exclusive technical videos. Try it free for 7 days!",
    "tryFree7Days": "TRY FREE FOR 7 DAYS",
    "areYouSure": "Are you sure?",
    "loseProgressWarning": "You will lose all your lesson progress if you exit.",
    "cancelUpper": "CANCEL",
    "exitUpper": "EXIT",
    "noQuestionsRegistered": "No questions registered",
    "noQuestionsAdminContact": "This lesson does not have registered questions in the system yet. Please contact the administrator.",
    "backButton": "BACK",
    "loadingQuestions": "Loading questions...",
    "questionProgress": "Question {current} of {total}",
    "verifyButton": "VERIFY",
    "excellentFeedback": "Excellent!",
    "payAttentionFeedback": "Pay attention to detail!",
    "finishButton": "FINISH",
    "falseUpper": "FALSE",
    "trueUpper": "TRUE",
    "noStatement": "No statement"
}

keys_es = {
    "epicStreakBonus": "¡RACHA ÉPICA! ¡+100 XP Extra!",
    "streakBonusEnergy": "¡Acierto en racha! ¡+{bonus} energía extra!",
    "successMessage": "¡Felicidades! ¡Alcanzaste {pct}% de aciertos y ganaste {xpEarned} XP!",
    "evaluationPassed": "¡Evaluación Aprobada!",
    "lessonCompleted": "¡Lección completada!",
    "insufficientPerformance": "Rendimiento Insuficiente",
    "performanceLow": "Obtuviste {score}%. Se requiere un mínimo de {required} para avanzar. Revisa el material e inténtalo de nuevo.",
    "continueButton": "CONTINUAR",
    "redoButton": "REHACER",
    "exitButton": "Salir",
    "batteryDepleted": "¡Batería Agotada!",
    "batteryDepletedDescription": "Has gastado toda tu energía. Espera la recarga automática (5 min por unidad) o suscríbete a un plan para tener batería infinita ∞.",
    "viewPlansInfiniteBattery": "VER PLANES CON BATERÍA ∞",
    "exitQuiz": "Salir del Quiz",
    "skipButton": "Omitir ✕",
    "powerplayTitle": "POWERPLAY",
    "congratsModule": "¡Felicidades por el módulo!",
    "tryPremiumVideosFree": "Sigue aprendiendo con videos técnicos exclusivos. ¡Pruébalo gratis por 7 días!",
    "tryFree7Days": "PRUEBA GRATIS POR 7 DÍAS",
    "areYouSure": "¿Estás seguro?",
    "loseProgressWarning": "Perderás todo el progreso de tu lección si sales.",
    "cancelUpper": "CANCELAR",
    "exitUpper": "SALIR",
    "noQuestionsRegistered": "Sin preguntas registradas",
    "noQuestionsAdminContact": "Esta lección aún no tiene preguntas registradas en el sistema. Por favor, contacta al administrador.",
    "backButton": "VOLVER",
    "loadingQuestions": "Cargando preguntas...",
    "questionProgress": "Pregunta {current} de {total}",
    "verifyButton": "VERIFICAR",
    "excellentFeedback": "¡Excelente!",
    "payAttentionFeedback": "¡Atención al detalle!",
    "finishButton": "FINALIZAR",
    "falseUpper": "FALSO",
    "trueUpper": "VERDADERO",
    "noStatement": "Sin enunciado"
}

replacements = [
    ("'STREAK ÉPICO! +100 XP Bônus!'", "AppLocalizations.of(context)!.epicStreakBonus"),
    ("'Acerto em sequência! +\\$bonus energia bônus!'", "AppLocalizations.of(context)!.streakBonusEnergy(bonus)"),
    ("return 'Parab\\\\u00e9ns! Voc\\\\u00ea alcan\\\\u00e7ou \\$pct% de acertos e ganhou \\$xpEarned XP!';", "return AppLocalizations.of(context)!.successMessage(pct, xpEarned);"),
    ("widget.isEvaluation ? 'Avaliação Aprovada!' : 'Lição concluída!'", "widget.isEvaluation ? AppLocalizations.of(context)!.evaluationPassed : AppLocalizations.of(context)!.lessonCompleted"),
    ("'Desempenho Insuficiente'", "AppLocalizations.of(context)!.insufficientPerformance"),
    ("'Você obteve \\${(score * 100).toInt()}%. É necessário no mínimo \\${widget.isEvaluation ? \\'80%\\' : \\'70%\\'} para avançar. Revise o material e tente novamente.'", "AppLocalizations.of(context)!.performanceLow((score * 100).toInt(), widget.isEvaluation ? '80%' : '70%')"),
    ("passed ? 'CONTINUAR' : 'REFAZER'", "passed ? AppLocalizations.of(context)!.continueButton : AppLocalizations.of(context)!.redoButton"),
    ("'Sair'", "AppLocalizations.of(context)!.exitButton"),
    ("'Bateria Esgotada!'", "AppLocalizations.of(context)!.batteryDepleted"),
    ("'Você gastou toda a sua energia. Aguarde a recarga automática (5 min por unidade) ou assine um plano para ter bateria infinita ∞.'", "AppLocalizations.of(context)!.batteryDepletedDescription"),
    ("'VER PLANOS COM BATERIA ∞'", "AppLocalizations.of(context)!.viewPlansInfiniteBattery"),
    ("'Sair do Quiz'", "AppLocalizations.of(context)!.exitQuiz"),
    ("'Pular ✕'", "AppLocalizations.of(context)!.skipButton"),
    ("'POWERPLAY'", "AppLocalizations.of(context)!.powerplayTitle"),
    ("'Parabens pelo modulo!'", "AppLocalizations.of(context)!.congratsModule"),
    ("'Continue aprendendo com vídeos técnicos exclusivos. Experimente grátis por 7 dias!'", "AppLocalizations.of(context)!.tryPremiumVideosFree"),
    ("'TESTE GRÁTIS POR 7 DIAS'", "AppLocalizations.of(context)!.tryFree7Days"),
    ("'Tem certeza?'", "AppLocalizations.of(context)!.areYouSure"),
    ("'Você vai perder todo seu progresso na lição se sair.'", "AppLocalizations.of(context)!.loseProgressWarning"),
    ("'CANCELAR'", "AppLocalizations.of(context)!.cancelUpper"),
    ("'SAIR'", "AppLocalizations.of(context)!.exitUpper"),
    ("'Nenhuma questão cadastrada'", "AppLocalizations.of(context)!.noQuestionsRegistered"),
    ("'Esta lição ainda não possui questões cadastradas no sistema. '\n                    'Por favor, entre em contato com o administrador.'", "AppLocalizations.of(context)!.noQuestionsAdminContact"),
    ("'VOLTAR'", "AppLocalizations.of(context)!.backButton"),
    ("'Carregando questões...'", "AppLocalizations.of(context)!.loadingQuestions"),
    ("'Pergunta \\${_currentQuestion + 1} de \\${_questions.length}'", "AppLocalizations.of(context)!.questionProgress(_currentQuestion + 1, _questions.length)"),
    ("'VERIFICAR'", "AppLocalizations.of(context)!.verifyButton"),
    ("passed ? 'Excelente!' : 'Atenção ao detalhe!'", "passed ? AppLocalizations.of(context)!.excellentFeedback : AppLocalizations.of(context)!.payAttentionFeedback"),
    ("_isCorrect ? 'Excelente!' : 'Atenção ao detalhe!'", "_isCorrect ? AppLocalizations.of(context)!.excellentFeedback : AppLocalizations.of(context)!.payAttentionFeedback"),
    ("_currentQuestion + 1 >= _questions.length ? 'FINALIZAR' : 'CONTINUAR'", "_currentQuestion + 1 >= _questions.length ? AppLocalizations.of(context)!.finishButton : AppLocalizations.of(context)!.continueButton"),
    ("'FALSO'", "AppLocalizations.of(context)!.falseUpper"),
    ("'VERDADEIRO'", "AppLocalizations.of(context)!.trueUpper"),
    ("isTrue ? 'VERDADEIRO' : 'FALSO'", "isTrue ? AppLocalizations.of(context)!.trueUpper : AppLocalizations.of(context)!.falseUpper"),
    ("'Sem enunciado'", "AppLocalizations.of(context)!.noStatement")
]

add_keys(keys_pt, keys_en, keys_es, keys_pt_meta)
replace_in_file('lib/screens/quiz_screen.dart', replacements)
print("Updated quiz_screen.dart")
