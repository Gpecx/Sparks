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
    "moduleLockedPreviousSteps": "Módulo bloqueado! Conclua as etapas anteriores primeiro.",
    "lessonCompletedTitle": "Lição Concluída!",
    "lessonCompletedWarning": "Você já completou esta lição. Para manter o desafio, refazê-la não está disponível no momento.",
    "understoodButton": "ENTENDIDO",
    "errorCategoryOrModuleMissing": "Erro: Categoria ou Módulo ausente",
    "currentModuleTitle": "Módulo Atual",
    "inProgressModuleSteps": "Em Progresso · {completed} de {total} etapas",
    "noLessonsFoundForModule": "Nenhuma lição encontrada para este módulo",
    "errorPrefix": "Erro: ",
    "membersOnlineHere": "{count, plural, =0{Nenhum membro online} =1{1 membro online aqui} other{{count} membros online aqui}}",
    "unlockFullPotentialPremium": "Desbloqueie o potencial completo com o Spark Premium.",
    "viewPlansButton": "CONHECER PLANOS",
    "proUpgradeTitle": "Conteúdo Premium",
    "proUpgradeDescription": "Este conteúdo é exclusivo para assinantes Premium.",
    "cancel": "Cancelar",
    "subscribe": "Assinar"
}

keys_pt_meta = {
    "@inProgressModuleSteps": {
        "placeholders": {
            "completed": {"type": "int"},
            "total": {"type": "int"}
        }
    },
    "@membersOnlineHere": {
        "placeholders": {
            "count": {"type": "int"}
        }
    }
}

keys_en = {
    "moduleLockedPreviousSteps": "Module locked! Complete previous steps first.",
    "lessonCompletedTitle": "Lesson Completed!",
    "lessonCompletedWarning": "You have already completed this lesson. To keep the challenge, retaking it is not available at the moment.",
    "understoodButton": "UNDERSTOOD",
    "errorCategoryOrModuleMissing": "Error: Missing Category or Module",
    "currentModuleTitle": "Current Module",
    "inProgressModuleSteps": "In Progress · {completed} of {total} steps",
    "noLessonsFoundForModule": "No lessons found for this module",
    "errorPrefix": "Error: ",
    "membersOnlineHere": "{count, plural, =0{No members online} =1{1 member online here} other{{count} members online here}}",
    "unlockFullPotentialPremium": "Unlock the full potential with Spark Premium.",
    "viewPlansButton": "VIEW PLANS",
    "proUpgradeTitle": "Premium Content",
    "proUpgradeDescription": "This content is exclusive for Premium subscribers.",
    "cancel": "Cancel",
    "subscribe": "Subscribe"
}

keys_es = {
    "moduleLockedPreviousSteps": "¡Módulo bloqueado! Completa los pasos anteriores primero.",
    "lessonCompletedTitle": "¡Lección Completada!",
    "lessonCompletedWarning": "Ya has completado esta lección. Para mantener el desafío, no está disponible rehacerla en este momento.",
    "understoodButton": "ENTENDIDO",
    "errorCategoryOrModuleMissing": "Error: Categoría o Módulo ausente",
    "currentModuleTitle": "Módulo Actual",
    "inProgressModuleSteps": "En Progreso · {completed} de {total} etapas",
    "noLessonsFoundForModule": "No se encontraron lecciones para este módulo",
    "errorPrefix": "Error: ",
    "membersOnlineHere": "{count, plural, =0{Sin miembros online} =1{1 miembro online aquí} other{{count} miembros online aquí}}",
    "unlockFullPotentialPremium": "Desbloquea el potencial completo con Spark Premium.",
    "viewPlansButton": "VER PLANES",
    "proUpgradeTitle": "Contenido Premium",
    "proUpgradeDescription": "Este contenido es exclusivo para suscriptores Premium.",
    "cancel": "Cancelar",
    "subscribe": "Suscribirse"
}

replacements = [
    ("'Módulo bloqueado! Conclua as etapas anteriores primeiro.'", "AppLocalizations.of(context)!.moduleLockedPreviousSteps"),
    ("'Lição Concluída!'", "AppLocalizations.of(context)!.lessonCompletedTitle"),
    ("'Você já completou esta lição. Para manter o desafio, refazê-la não está disponível no momento.'", "AppLocalizations.of(context)!.lessonCompletedWarning"),
    ("'ENTENDIDO'", "AppLocalizations.of(context)!.understoodButton"),
    ("'Erro: Categoria ou Módulo ausente'", "AppLocalizations.of(context)!.errorCategoryOrModuleMissing"),
    ("'Módulo Atual'", "AppLocalizations.of(context)!.currentModuleTitle"),
    ("'Em Progresso · \\$completedLessons de \\$totalLessons etapas'", "AppLocalizations.of(context)!.inProgressModuleSteps(completedLessons, totalLessons)"),
    ("'Nenhuma lição encontrada para este módulo'", "AppLocalizations.of(context)!.noLessonsFoundForModule"),
    ("Text('Erro: \\$e'", "Text(AppLocalizations.of(context)!.errorPrefix + e.toString()"),
    ("Text('\\$count membros online aqui'", "Text(AppLocalizations.of(context)!.membersOnlineHere(count)"),
    ("'Desbloqueie o potencial completo com o Spark Premium.'", "AppLocalizations.of(context)!.unlockFullPotentialPremium"),
    ("'CONHECER PLANOS'", "AppLocalizations.of(context)!.viewPlansButton")
]

replace_in_file('lib/screens/learning_path_screen.dart', replacements)
print("Updated learning_path_screen.dart")
add_keys(keys_pt, keys_en, keys_es, keys_pt_meta)
