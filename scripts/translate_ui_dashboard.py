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
    "goodMorning": "Bom dia",
    "goodAfternoon": "Boa tarde",
    "goodEvening": "Boa noite",
    "myProfileMenu": "Meu Perfil",
    "settingsMenu": "Configurações",
    "adminPanelMenu": "Painel Admin",
    "myAchievementsMenu": "Minhas Conquistas",
    "myProgressMenu": "Meu Progresso",
    "helpSupportMenu": "Ajuda / Suporte",
    "newMechanicsHeader": "NOVAS MECÂNICAS",
    "sparksDuelMenu": "Duelo de Faíscas (PvP)",
    "logoutMenu": "Sair",
    "seeAllPlural": "Ver todas",
    "notificationsTitle": "Notificações",
    "markAllAsRead": "Marcar todas como lidas",
    "noNotificationsAtMoment": "Nenhuma notificação no momento.",
    "weeklyCovenantsTitle": "Pactos Semanais",
    "featuredModulesTitle": "Módulos em Destaque",
    "yourProgressTitle": "Seu Progresso",
    "technicianLevel": "Técnico Nível {level}",
    "streakMultiplierMessage": "🔥 Streak de {streak} dias! Multiplicador de {multiplier}x.",
    "streakDays": "{streak} Dias",
    "xpProgress": "{current} / {total} XP",
    "totalXp": "XP Total: {xp} XP",
    "dailyChallengeTitle": "Desafio Diário",
    "adminTestAccess": "Acesso Teste Admin",
    "comingSoonLabel": "Em breve...",
    "comingSoonUpper": "EM BREVE",
    "moduleFallback": "Módulo {id}",
    "noModuleStarted": "Nenhum módulo iniciado",
    "lessonsCompleted": "{count, plural, =0{0 lições concluídas} =1{1 lição concluída} other{{count} lições concluídas}}",
    "accessLearningPathToStart": "Acesse o Caminho de Aprendizado para começar",
    "continueLearningTitle": "Continue Aprendendo",
    "dailyChallengeDescription": "Teste seus conhecimentos em NR-10! Complete 3 perguntas rápidas para receber recompensas.",
    "rewardXp": "💰 +{xp} XP",
    "rewardLabel": "Recompensa",
    "estimatedTime": "⏱️ {time} min",
    "estimatedTimeLabel": "Tempo Est.",
    "notNowButton": "AGORA NÃO",
    "startChallengeButton": "INICIAR DESAFIO",
    "startingDailyChallenge": "Iniciando desafio diário...",
    "noActiveCovenant": "Nenhum Pacto Ativo",
    "goToCovenantsTabToCreate": "Vá até a aba Pactos para criar o compromisso!",
    "acceptCovenantButton": "ACEITAR PACTO",
    "covenantProgress": "{current}/{max} {type}",
    "noFeaturedModulesCurrently": "Nenhum módulo em destaque no momento.",
    "continueExploringForNewContent": "Continue explorando para descobrir novos conteúdos!",
    "errorLoadingModules": "Erro ao carregar módulos",
    "powerplayStreamingTitle": "PowerPlay Streaming",
    "technicalVideosDescription": "Vídeos técnicos e conteúdos exclusivos para seu aprendizado",
    "learnMoreButton": "Saiba mais",
    "errorLoadingProgress": "Erro ao carregar progresso"
}

keys_pt_meta = {
    "@technicianLevel": { "placeholders": { "level": { "type": "int" } } },
    "@streakMultiplierMessage": { "placeholders": { "streak": { "type": "int" }, "multiplier": { "type": "double" } } },
    "@streakDays": { "placeholders": { "streak": { "type": "int" } } },
    "@xpProgress": { "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } } },
    "@totalXp": { "placeholders": { "xp": { "type": "int" } } },
    "@moduleFallback": { "placeholders": { "id": { "type": "String" } } },
    "@lessonsCompleted": { "placeholders": { "count": { "type": "int" } } },
    "@rewardXp": { "placeholders": { "xp": { "type": "int" } } },
    "@estimatedTime": { "placeholders": { "time": { "type": "int" } } },
    "@covenantProgress": { "placeholders": { "current": { "type": "int" }, "max": { "type": "int" }, "type": { "type": "String" } } }
}

keys_en = {
    "goodMorning": "Good morning",
    "goodAfternoon": "Good afternoon",
    "goodEvening": "Good evening",
    "myProfileMenu": "My Profile",
    "settingsMenu": "Settings",
    "adminPanelMenu": "Admin Panel",
    "myAchievementsMenu": "My Achievements",
    "myProgressMenu": "My Progress",
    "helpSupportMenu": "Help / Support",
    "newMechanicsHeader": "NEW MECHANICS",
    "sparksDuelMenu": "Sparks Duel (PvP)",
    "logoutMenu": "Logout",
    "seeAllPlural": "See all",
    "notificationsTitle": "Notifications",
    "markAllAsRead": "Mark all as read",
    "noNotificationsAtMoment": "No notifications at the moment.",
    "weeklyCovenantsTitle": "Weekly Covenants",
    "featuredModulesTitle": "Featured Modules",
    "yourProgressTitle": "Your Progress",
    "technicianLevel": "Technician Level {level}",
    "streakMultiplierMessage": "🔥 {streak} day streak! {multiplier}x multiplier.",
    "streakDays": "{streak} Days",
    "xpProgress": "{current} / {total} XP",
    "totalXp": "Total XP: {xp} XP",
    "dailyChallengeTitle": "Daily Challenge",
    "adminTestAccess": "Admin Test Access",
    "comingSoonLabel": "Coming soon...",
    "comingSoonUpper": "COMING SOON",
    "moduleFallback": "Module {id}",
    "noModuleStarted": "No module started",
    "lessonsCompleted": "{count, plural, =0{0 lessons completed} =1{1 lesson completed} other{{count} lessons completed}}",
    "accessLearningPathToStart": "Access the Learning Path to start",
    "continueLearningTitle": "Continue Learning",
    "dailyChallengeDescription": "Test your NR-10 knowledge! Complete 3 quick questions to receive rewards.",
    "rewardXp": "💰 +{xp} XP",
    "rewardLabel": "Reward",
    "estimatedTime": "⏱️ {time} min",
    "estimatedTimeLabel": "Est. Time",
    "notNowButton": "NOT NOW",
    "startChallengeButton": "START CHALLENGE",
    "startingDailyChallenge": "Starting daily challenge...",
    "noActiveCovenant": "No Active Covenant",
    "goToCovenantsTabToCreate": "Go to the Covenants tab to create the commitment!",
    "acceptCovenantButton": "ACCEPT COVENANT",
    "covenantProgress": "{current}/{max} {type}",
    "noFeaturedModulesCurrently": "No featured modules currently.",
    "continueExploringForNewContent": "Continue exploring to discover new content!",
    "errorLoadingModules": "Error loading modules",
    "powerplayStreamingTitle": "PowerPlay Streaming",
    "technicalVideosDescription": "Technical videos and exclusive content for your learning",
    "learnMoreButton": "Learn more",
    "errorLoadingProgress": "Error loading progress"
}

keys_es = {
    "goodMorning": "Buenos días",
    "goodAfternoon": "Buenas tardes",
    "goodEvening": "Buenas noches",
    "myProfileMenu": "Mi Perfil",
    "settingsMenu": "Configuraciones",
    "adminPanelMenu": "Panel de Admin",
    "myAchievementsMenu": "Mis Logros",
    "myProgressMenu": "Mi Progreso",
    "helpSupportMenu": "Ayuda / Soporte",
    "newMechanicsHeader": "NUEVAS MECÁNICAS",
    "sparksDuelMenu": "Duelo de Chispas (PvP)",
    "logoutMenu": "Salir",
    "seeAllPlural": "Ver todas",
    "notificationsTitle": "Notificaciones",
    "markAllAsRead": "Marcar todas como leídas",
    "noNotificationsAtMoment": "No hay notificaciones en este momento.",
    "weeklyCovenantsTitle": "Pactos Semanales",
    "featuredModulesTitle": "Módulos Destacados",
    "yourProgressTitle": "Tu Progreso",
    "technicianLevel": "Técnico Nivel {level}",
    "streakMultiplierMessage": "🔥 ¡Racha de {streak} días! Multiplicador de {multiplier}x.",
    "streakDays": "{streak} Días",
    "xpProgress": "{current} / {total} XP",
    "totalXp": "XP Total: {xp} XP",
    "dailyChallengeTitle": "Desafío Diario",
    "adminTestAccess": "Acceso de Prueba Admin",
    "comingSoonLabel": "Próximamente...",
    "comingSoonUpper": "PRÓXIMAMENTE",
    "moduleFallback": "Módulo {id}",
    "noModuleStarted": "Ningún módulo iniciado",
    "lessonsCompleted": "{count, plural, =0{0 lecciones completadas} =1{1 lección completada} other{{count} lecciones completadas}}",
    "accessLearningPathToStart": "Accede a la Ruta de Aprendizaje para comenzar",
    "continueLearningTitle": "Continúa Aprendiendo",
    "dailyChallengeDescription": "¡Pon a prueba tus conocimientos en NR-10! Completa 3 preguntas rápidas para recibir recompensas.",
    "rewardXp": "💰 +{xp} XP",
    "rewardLabel": "Recompensa",
    "estimatedTime": "⏱️ {time} min",
    "estimatedTimeLabel": "Tiempo Est.",
    "notNowButton": "AHORA NO",
    "startChallengeButton": "INICIAR DESAFÍO",
    "startingDailyChallenge": "Iniciando desafío diario...",
    "noActiveCovenant": "Ningún Pacto Activo",
    "goToCovenantsTabToCreate": "¡Ve a la pestaña Pactos para crear el compromiso!",
    "acceptCovenantButton": "ACEPTAR PACTO",
    "covenantProgress": "{current}/{max} {type}",
    "noFeaturedModulesCurrently": "No hay módulos destacados en este momento.",
    "continueExploringForNewContent": "¡Sigue explorando para descubrir nuevo contenido!",
    "errorLoadingModules": "Error al cargar módulos",
    "powerplayStreamingTitle": "PowerPlay Streaming",
    "technicalVideosDescription": "Videos técnicos y contenido exclusivo para tu aprendizaje",
    "learnMoreButton": "Saber más",
    "errorLoadingProgress": "Error al cargar el progreso"
}

replacements = [
    ("return 'Bom dia'", "return AppLocalizations.of(context)!.goodMorning"),
    ("return 'Boa tarde'", "return AppLocalizations.of(context)!.goodAfternoon"),
    ("return 'Boa noite'", "return AppLocalizations.of(context)!.goodEvening"),
    ("'Meu Perfil'", "AppLocalizations.of(context)!.myProfileMenu"),
    ("'Configurações'", "AppLocalizations.of(context)!.settingsMenu"),
    ("'Painel Admin'", "AppLocalizations.of(context)!.adminPanelMenu"),
    ("'Minhas Conquistas'", "AppLocalizations.of(context)!.myAchievementsMenu"),
    ("'Meu Progresso'", "AppLocalizations.of(context)!.myProgressMenu"),
    ("'Ajuda / Suporte'", "AppLocalizations.of(context)!.helpSupportMenu"),
    ("'NOVAS MECÂNICAS'", "AppLocalizations.of(context)!.newMechanicsHeader"),
    ("'Duelo de Faíscas (PvP)'", "AppLocalizations.of(context)!.sparksDuelMenu"),
    ("'Sair'", "AppLocalizations.of(context)!.logoutMenu"),
    ("'Ver todas'", "AppLocalizations.of(context)!.seeAllPlural"),
    ("'Notificações'", "AppLocalizations.of(context)!.notificationsTitle"),
    ("'Marcar todas como lidas'", "AppLocalizations.of(context)!.markAllAsRead"),
    ("'Nenhuma notificação no momento.'", "AppLocalizations.of(context)!.noNotificationsAtMoment"),
    ("'Pactos Semanais'", "AppLocalizations.of(context)!.weeklyCovenantsTitle"),
    ("'Módulos em Destaque'", "AppLocalizations.of(context)!.featuredModulesTitle"),
    ("'Seu Progresso'", "AppLocalizations.of(context)!.yourProgressTitle"),
    ("'Técnico Nível \\$level'", "AppLocalizations.of(context)!.technicianLevel(level)"),
    ("'🔥 Streak de \\$streak dias! Multiplicador de \\${multiplier}x.'", "AppLocalizations.of(context)!.streakMultiplierMessage(streak, multiplier)"),
    ("'\\$streak Dias'", "AppLocalizations.of(context)!.streakDays(streak)"),
    ("'\\$xpInCurrentLevel / 500 XP'", "AppLocalizations.of(context)!.xpProgress(xpInCurrentLevel, 500)"),
    ("'XP Total: \\$xp XP'", "AppLocalizations.of(context)!.totalXp(xp)"),
    ("'Desafio Diário'", "AppLocalizations.of(context)!.dailyChallengeTitle"),
    ("'Acesso Teste Admin'", "AppLocalizations.of(context)!.adminTestAccess"),
    ("'Em breve...'", "AppLocalizations.of(context)!.comingSoonLabel"),
    ("'EM BREVE'", "AppLocalizations.of(context)!.comingSoonUpper"),
    ("'Módulo \\${lastModule.moduleId.split(\\'_\\').last}'", "AppLocalizations.of(context)!.moduleFallback(lastModule.moduleId.split('_').last)"),
    ("'Nenhum módulo iniciado'", "AppLocalizations.of(context)!.noModuleStarted"),
    ("'\\${lastModule.completedLessons.length} lição(ões) concluída(s)'", "AppLocalizations.of(context)!.lessonsCompleted(lastModule.completedLessons.length)"),
    ("'Acesse o Caminho de Aprendizado para começar'", "AppLocalizations.of(context)!.accessLearningPathToStart"),
    ("'Continue Aprendendo'", "AppLocalizations.of(context)!.continueLearningTitle"),
    ("'Teste seus conhecimentos em NR-10! Complete 3 perguntas rápidas para receber recompensas.'", "AppLocalizations.of(context)!.dailyChallengeDescription"),
    ("'💰 +50 XP'", "AppLocalizations.of(context)!.rewardXp(50)"),
    ("'Recompensa'", "AppLocalizations.of(context)!.rewardLabel"),
    ("'⏱️ 3 min'", "AppLocalizations.of(context)!.estimatedTime(3)"),
    ("'Tempo Est.'", "AppLocalizations.of(context)!.estimatedTimeLabel"),
    ("'AGORA NÃO'", "AppLocalizations.of(context)!.notNowButton"),
    ("'INICIAR DESAFIO'", "AppLocalizations.of(context)!.startChallengeButton"),
    ("'Iniciando desafio diário...'", "AppLocalizations.of(context)!.startingDailyChallenge"),
    ("'Nenhum Pacto Ativo'", "AppLocalizations.of(context)!.noActiveCovenant"),
    ("'Vá até a aba Pactos para criar o compromisso!'", "AppLocalizations.of(context)!.goToCovenantsTabToCreate"),
    ("'ACEITAR PACTO'", "AppLocalizations.of(context)!.acceptCovenantButton"),
    ("'\\$realProgress/\\${cov.maxProgress} \\${cov.trackingType}'", "AppLocalizations.of(context)!.covenantProgress(realProgress, cov.maxProgress, cov.trackingType)"),
    ("'Nenhum módulo em destaque no momento.'", "AppLocalizations.of(context)!.noFeaturedModulesCurrently"),
    ("'Continue explorando para descobrir novos conteúdos!'", "AppLocalizations.of(context)!.continueExploringForNewContent"),
    ("'Erro ao carregar módulos'", "AppLocalizations.of(context)!.errorLoadingModules"),
    ("'PowerPlay Streaming'", "AppLocalizations.of(context)!.powerplayStreamingTitle"),
    ("'Vídeos técnicos e conteúdos exclusivos para seu aprendizado'", "AppLocalizations.of(context)!.technicalVideosDescription"),
    ("'Saiba mais'", "AppLocalizations.of(context)!.learnMoreButton"),
    ("'Erro ao carregar progresso'", "AppLocalizations.of(context)!.errorLoadingProgress")
]

add_keys(keys_pt, keys_en, keys_es, keys_pt_meta)
replace_in_file('lib/screens/dashboard_screen.dart', replacements)
print("Updated dashboard_screen.dart")
