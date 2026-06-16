import json
import re

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
    "accessDeniedAdminOnly": "Acesso Negado: Apenas administradores podem ativar o Modo Dev.",
    "devModeTapsRemaining": "🔧 Dev: {remaining} toque(s) restantes...",
    "devModeDisabled": "🔒 Modo Dev DESATIVADO",
    "devModeEnabled": "🔓 Modo Dev ATIVADO — Painel Admin Liberado!",
    "myProfile": "MEU PERFIL",
    "levelValue": "Lvl {level}",
    "technicianRole": "TÉCNICO",
    "viewCredential": "VER CREDENCIAL",
    "activeDays": "Dias Ativos",
    "daysLabel": "dias",
    "streakLabel": "Streak",
    "streakDaysFire": "dias 🔥",
    "experienceLabel": "Experiência",
    "xpLabel": "XP",
    "debugInfoTitle": "DEBUG INFO (MODO DEV)",
    "debugUid": "UID: {uid}",
    "debugRole": "Role Firestore: {role}",
    "debugIsAdmin": "isAdmin Getter: {isAdmin}",
    "adminPanel": "PAINEL ADMINISTRATIVO",
    "achievementsTitle": "CONQUISTAS",
    "seeAll": "Ver Tudo ↗",
    "noAchievementsYet": "Você não tem conquistas no momento.",
    "letsLearnAndUnlockRewards": "Bora aprender e desbloquear recompensas!",
    "clanTitle": "CLÃ",
    "joinAClan": "Faça parte de um Clã!",
    "clanDescription": "Junte-se a outros alunos, compita em equipe e ganhe recompensas exclusivas.",
    "createClanUpper": "CRIAR CLÃ",
    "enterUpper": "ENTRAR",
    "myClanTitle": "MEU CLÃ",
    "clanMemberRole": "Membro",
    "viewClanUpper": "VISUALIZAR CLÃ",
    "weeklyRankingTitle": "RANKING SEMANAL",
    "globalLeaderboard": "Placar Global",
    "yourRankingPosition": "Você está em {position}º lugar esta semana",
    "completeLessonsToEnterRanking": "Complete lições para entrar no ranking",
    "myClanFallback": "Meu Clã"
}

keys_pt_meta = {
    "@devModeTapsRemaining": { "placeholders": { "remaining": { "type": "int" } } },
    "@levelValue": { "placeholders": { "level": { "type": "int" } } },
    "@debugUid": { "placeholders": { "uid": { "type": "String" } } },
    "@debugRole": { "placeholders": { "role": { "type": "String" } } },
    "@debugIsAdmin": { "placeholders": { "isAdmin": { "type": "String" } } },
    "@yourRankingPosition": { "placeholders": { "position": { "type": "int" } } }
}

keys_en = {
    "accessDeniedAdminOnly": "Access Denied: Only administrators can activate Dev Mode.",
    "devModeTapsRemaining": "🔧 Dev: {remaining} tap(s) remaining...",
    "devModeDisabled": "🔒 Dev Mode DISABLED",
    "devModeEnabled": "🔓 Dev Mode ENABLED — Admin Panel Unlocked!",
    "myProfile": "MY PROFILE",
    "levelValue": "Lvl {level}",
    "technicianRole": "TECHNICIAN",
    "viewCredential": "VIEW CREDENTIAL",
    "activeDays": "Active Days",
    "daysLabel": "days",
    "streakLabel": "Streak",
    "streakDaysFire": "days 🔥",
    "experienceLabel": "Experience",
    "xpLabel": "XP",
    "debugInfoTitle": "DEBUG INFO (DEV MODE)",
    "debugUid": "UID: {uid}",
    "debugRole": "Firestore Role: {role}",
    "debugIsAdmin": "isAdmin Getter: {isAdmin}",
    "adminPanel": "ADMINISTRATIVE PANEL",
    "achievementsTitle": "ACHIEVEMENTS",
    "seeAll": "See All ↗",
    "noAchievementsYet": "You have no achievements at the moment.",
    "letsLearnAndUnlockRewards": "Let's learn and unlock rewards!",
    "clanTitle": "CLAN",
    "joinAClan": "Join a Clan!",
    "clanDescription": "Join other students, compete as a team and earn exclusive rewards.",
    "createClanUpper": "CREATE CLAN",
    "enterUpper": "ENTER",
    "myClanTitle": "MY CLAN",
    "clanMemberRole": "Member",
    "viewClanUpper": "VIEW CLAN",
    "weeklyRankingTitle": "WEEKLY RANKING",
    "globalLeaderboard": "Global Leaderboard",
    "yourRankingPosition": "You are in {position}th place this week",
    "completeLessonsToEnterRanking": "Complete lessons to enter the ranking",
    "myClanFallback": "My Clan"
}

keys_es = {
    "accessDeniedAdminOnly": "Acceso Denegado: Solo los administradores pueden activar el Modo Dev.",
    "devModeTapsRemaining": "🔧 Dev: {remaining} toque(s) restante(s)...",
    "devModeDisabled": "🔒 Modo Dev DESACTIVADO",
    "devModeEnabled": "🔓 Modo Dev ACTIVADO — Panel Admin Desbloqueado!",
    "myProfile": "MI PERFIL",
    "levelValue": "Lvl {level}",
    "technicianRole": "TÉCNICO",
    "viewCredential": "VER CREDENCIAL",
    "activeDays": "Días Activos",
    "daysLabel": "días",
    "streakLabel": "Racha",
    "streakDaysFire": "días 🔥",
    "experienceLabel": "Experiencia",
    "xpLabel": "XP",
    "debugInfoTitle": "INFO DEBUG (MODO DEV)",
    "debugUid": "UID: {uid}",
    "debugRole": "Rol Firestore: {role}",
    "debugIsAdmin": "isAdmin Getter: {isAdmin}",
    "adminPanel": "PANEL ADMINISTRATIVO",
    "achievementsTitle": "LOGROS",
    "seeAll": "Ver Todo ↗",
    "noAchievementsYet": "No tienes logros por el momento.",
    "letsLearnAndUnlockRewards": "¡Vamos a aprender y desbloquear recompensas!",
    "clanTitle": "CLAN",
    "joinAClan": "¡Forma parte de un Clan!",
    "clanDescription": "Únete a otros estudiantes, compite en equipo y gana recompensas exclusivas.",
    "createClanUpper": "CREAR CLAN",
    "enterUpper": "ENTRAR",
    "myClanTitle": "MI CLAN",
    "clanMemberRole": "Miembro",
    "viewClanUpper": "VER CLAN",
    "weeklyRankingTitle": "RANKING SEMANAL",
    "globalLeaderboard": "Marcador Global",
    "yourRankingPosition": "Estás en el {position}º lugar esta semana",
    "completeLessonsToEnterRanking": "Completa lecciones para entrar al ranking",
    "myClanFallback": "Mi Clan"
}

replacements = [
    ("'Acesso Negado: Apenas administradores podem ativar o Modo Dev.'", "AppLocalizations.of(context)!.accessDeniedAdminOnly"),
    ("'🔧 Dev: \\$remaining toque(s) restantes...'", "AppLocalizations.of(context)!.devModeTapsRemaining(remaining)"),
    ("'🔒 Modo Dev DESATIVADO'", "AppLocalizations.of(context)!.devModeDisabled"),
    ("'🔓 Modo Dev ATIVADO — Painel Admin Liberado!'", "AppLocalizations.of(context)!.devModeEnabled"),
    ("'MEU PERFIL'", "AppLocalizations.of(context)!.myProfile"),
    ("'Lvl \\${userService.level}'", "AppLocalizations.of(context)!.levelValue(userService.level)"),
    ("'TÉCNICO'", "AppLocalizations.of(context)!.technicianRole"),
    ("'VER CREDENCIAL'", "AppLocalizations.of(context)!.viewCredential"),
    ("'Dias Ativos'", "AppLocalizations.of(context)!.activeDays"),
    ("'dias'", "AppLocalizations.of(context)!.daysLabel"),
    ("'Streak'", "AppLocalizations.of(context)!.streakLabel"),
    ("'dias 🔥'", "AppLocalizations.of(context)!.streakDaysFire"),
    ("'Experiência'", "AppLocalizations.of(context)!.experienceLabel"),
    ("'XP'", "AppLocalizations.of(context)!.xpLabel"),
    ("'DEBUG INFO (MODO DEV)'", "AppLocalizations.of(context)!.debugInfoTitle"),
    ("'UID: \\${userService.uid}'", "AppLocalizations.of(context)!.debugUid(userService.uid ?? '')"),
    ("'Role Firestore: \\${user?.role ?? \"Nula\"}'", "AppLocalizations.of(context)!.debugRole(user?.role ?? 'Nula')"),
    ("'isAdmin Getter: \\${user?.isAdmin ?? \"false\"}'", "AppLocalizations.of(context)!.debugIsAdmin(user?.isAdmin.toString() ?? 'false')"),
    ("'PAINEL ADMINISTRATIVO'", "AppLocalizations.of(context)!.adminPanel"),
    ("'CONQUISTAS'", "AppLocalizations.of(context)!.achievementsTitle"),
    ("'Ver Tudo ↗'", "AppLocalizations.of(context)!.seeAll"),
    ("'Você não tem conquistas no momento.'", "AppLocalizations.of(context)!.noAchievementsYet"),
    ("'Bora aprender e desbloquear recompensas!'", "AppLocalizations.of(context)!.letsLearnAndUnlockRewards"),
    ("'CLÃ'", "AppLocalizations.of(context)!.clanTitle"),
    ("'Faça parte de um Clã!'", "AppLocalizations.of(context)!.joinAClan"),
    ("'Junte-se a outros alunos, compita em equipe e ganhe recompensas exclusivas.'", "AppLocalizations.of(context)!.clanDescription"),
    ("'CRIAR CLÃ'", "AppLocalizations.of(context)!.createClanUpper"),
    ("'ENTRAR'", "AppLocalizations.of(context)!.enterUpper"),
    ("'MEU CLÃ'", "AppLocalizations.of(context)!.myClanTitle"),
    ("'Membro'", "AppLocalizations.of(context)!.clanMemberRole"),
    ("'VISUALIZAR CLÃ'", "AppLocalizations.of(context)!.viewClanUpper"),
    ("'RANKING SEMANAL'", "AppLocalizations.of(context)!.weeklyRankingTitle"),
    ("'Placar Global'", "AppLocalizations.of(context)!.globalLeaderboard"),
    ("'Você está em \\$_rankingPositionº lugar esta semana'", "AppLocalizations.of(context)!.yourRankingPosition(_rankingPosition)"),
    ("'Complete lições para entrar no ranking'", "AppLocalizations.of(context)!.completeLessonsToEnterRanking"),
    ("'Meu Clã'", "AppLocalizations.of(context)!.myClanFallback")
]

add_keys(keys_pt, keys_en, keys_es, keys_pt_meta)
replace_in_file('lib/screens/profile_screen.dart', replacements)
print("Updated profile_screen.dart")
