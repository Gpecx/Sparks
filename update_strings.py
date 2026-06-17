import json
import os
import re

def add_keys(keys_pt, keys_en, keys_es):
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

    with open(files['pt'], 'w', encoding='utf-8') as f: json.dump(data_pt, f, indent=2, ensure_ascii=False)
    with open(files['en'], 'w', encoding='utf-8') as f: json.dump(data_en, f, indent=2, ensure_ascii=False)
    with open(files['es'], 'w', encoding='utf-8') as f: json.dump(data_es, f, indent=2, ensure_ascii=False)

def replace_in_file(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add import if missing
    import_stmt = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';"
    if import_stmt not in content:
        content = content.replace("import 'package:flutter/material.dart';", f"import 'package:flutter/material.dart';\n{import_stmt}")

    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

keys_pt = {
    "createClanTitle": "CRIAR CLÃ",
    "joinClanTitle": "ENTRAR EM UM CLÃ",
    "editClanNamePassword": "Editar Nome/Senha",
    "deleteClan": "Deletar Clã",
    "createClanDescription": "Crie um grupo para sua empresa e compete contra seus colegas!",
    "clanNameLabel": "Nome do Clã",
    "clanNameHint": "Ex: EXS Técnicos SP",
    "clanNameValidator": "Nome deve ter mais que 3 caracteres",
    "clanDescriptionLabel": "Descrição do Clã",
    "clanDescriptionHint": "Sobre o clã...",
    "clanPasswordLabel": "Senha do Clã",
    "clanPasswordHint": "Mínimo 4 caracteres",
    "clanPasswordValidator": "Senha deve ter pelo menos 4 caracteres",
    "createClanAdminNotice": "Como criador, você terá o cargo de ADMIN e poderá gerenciar todos os membros.",
    "createClanButton": "CRIAR GRUPO/CLÃ",
    "joinClanDescription": "Entre com código de convite ou com a senha do clã.",
    "inviteCodeOptionalLabel": "Código de Convite (opcional)",
    "inviteCodeHint": "Ex: SPARK-XK29",
    "clanPasswordJoinHint": "Digite a senha do grupo",
    "joinPasswordValidator": "Informe a senha ou o código",
    "joinClanButton": "ENTRAR NO GRUPO",
    "clanNotFound": "Clã não encontrado.",
    "clanMembersCount": "{count, plural, =0{Nenhum membro} =1{1 membro} other{{count} membros}}",
    "@clanMembersCount": {
        "placeholders": {
            "count": { "type": "int" }
        }
    },
    "maxLevel": "MÁXIMO",
    "currentLeague": "Liga Atual",
    "globalRank": "Rank Global",
    "membersListTitle": "MEMBROS",
    "clanChatTitle": "CHAT DO CLÃ",
    "chatSilent": "O chat está silencioso...",
    "beFirstToInteract": "Seja o primeiro a interagir!",
    "typeAMessage": "Digite uma mensagem...",
    "clanMascot": "Ícone do Clã",
    "weeklyQuestsTitle": "MISSÕES DA SEMANA",
    "noActiveQuests": "Nenhuma missão ativa.",
    "joinRequestsTitle": "PEDIDOS DE ENTRADA",
    "noPendingRequests": "Nenhum pedido pendente por enquanto.",
    "unknownMember": "Membro Desconhecido",
    "acceptJoinRequestSuccess": "Pedido aceito!",
    "rejectJoinRequestSuccess": "Pedido recusado!",
    "clanCreatedSuccess": "Clã criado com sucesso!",
    "errorCreatingClan": "Erro ao criar: ",
    "joinRequestSent": "Pedido de entrada enviado! Aguarde aprovação.",
    "joinedClanSuccess": "Você entrou no clã!",
    "errorJoiningClan": "Erro ao entrar: ",
    "editClanTitle": "Editar Clã",
    "newClanNameHint": "Novo nome do clã",
    "mainColorLabel": "COR PRINCIPAL",
    "clanIconLabel": "ÍCONE DO CLÃ",
    "cancelButton": "Cancelar",
    "saveButton": "SALVAR",
    "clanUpdatedSuccess": "Clã atualizado com sucesso!",
    "errorUpdatingClan": "Erro ao atualizar clã: ",
    "deleteClanDialogTitle": "Deletar Clã?",
    "deleteClanWarning": "Esta ação é permanente! Todos os membros serão removidos.",
    "deleteClanButton": "DELETAR",
    "clanDeletedSuccess": "Clã deletado com sucesso!",
    "errorDeletingClan": "Erro ao deletar: ",
    "clanLeaguesTitle": "Ligas do Clã",
    "closeButton": "Fechar",
    "inviteToClanTitle": "Convidar para o Clã",
    "shareCodeSubtitle": "Compartilhe o código abaixo",
    "inviteCodeInfo": "Qualquer pessoa com este código pode entrar no seu clã.",
    "codeCopied": "Código copiado!",
    "tapToCopy": "Toque no código para copiar",
    "copyCodeButton": "Copiar Código",
    "copiedButton": "Copiado!"
}

keys_en = {
    "createClanTitle": "CREATE CLAN",
    "joinClanTitle": "JOIN A CLAN",
    "editClanNamePassword": "Edit Name/Password",
    "deleteClan": "Delete Clan",
    "createClanDescription": "Create a group for your company and compete against your colleagues!",
    "clanNameLabel": "Clan Name",
    "clanNameHint": "Ex: EXS Technicians NY",
    "clanNameValidator": "Name must have more than 3 characters",
    "clanDescriptionLabel": "Clan Description",
    "clanDescriptionHint": "About the clan...",
    "clanPasswordLabel": "Clan Password",
    "clanPasswordHint": "Minimum 4 characters",
    "clanPasswordValidator": "Password must have at least 4 characters",
    "createClanAdminNotice": "As a creator, you will have the ADMIN role and can manage all members.",
    "createClanButton": "CREATE GROUP/CLAN",
    "joinClanDescription": "Enter with invite code or clan password.",
    "inviteCodeOptionalLabel": "Invite Code (optional)",
    "inviteCodeHint": "Ex: SPARK-XK29",
    "clanPasswordJoinHint": "Enter the group password",
    "joinPasswordValidator": "Enter the password or code",
    "joinClanButton": "JOIN GROUP",
    "clanNotFound": "Clan not found.",
    "clanMembersCount": "{count, plural, =0{No members} =1{1 member} other{{count} members}}",
    "maxLevel": "MAX",
    "currentLeague": "Current League",
    "globalRank": "Global Rank",
    "membersListTitle": "MEMBERS",
    "clanChatTitle": "CLAN CHAT",
    "chatSilent": "The chat is silent...",
    "beFirstToInteract": "Be the first to interact!",
    "typeAMessage": "Type a message...",
    "clanMascot": "Clan Icon",
    "weeklyQuestsTitle": "WEEKLY QUESTS",
    "noActiveQuests": "No active quests.",
    "joinRequestsTitle": "JOIN REQUESTS",
    "noPendingRequests": "No pending requests for now.",
    "unknownMember": "Unknown Member",
    "acceptJoinRequestSuccess": "Request accepted!",
    "rejectJoinRequestSuccess": "Request rejected!",
    "clanCreatedSuccess": "Clan successfully created!",
    "errorCreatingClan": "Error creating: ",
    "joinRequestSent": "Join request sent! Wait for approval.",
    "joinedClanSuccess": "You joined the clan!",
    "errorJoiningClan": "Error joining: ",
    "editClanTitle": "Edit Clan",
    "newClanNameHint": "New clan name",
    "mainColorLabel": "MAIN COLOR",
    "clanIconLabel": "CLAN ICON",
    "cancelButton": "Cancel",
    "saveButton": "SAVE",
    "clanUpdatedSuccess": "Clan successfully updated!",
    "errorUpdatingClan": "Error updating clan: ",
    "deleteClanDialogTitle": "Delete Clan?",
    "deleteClanWarning": "This action is permanent! All members will be removed.",
    "deleteClanButton": "DELETE",
    "clanDeletedSuccess": "Clan successfully deleted!",
    "errorDeletingClan": "Error deleting: ",
    "clanLeaguesTitle": "Clan Leagues",
    "closeButton": "Close",
    "inviteToClanTitle": "Invite to Clan",
    "shareCodeSubtitle": "Share the code below",
    "inviteCodeInfo": "Anyone with this code can join your clan.",
    "codeCopied": "Code copied!",
    "tapToCopy": "Tap the code to copy",
    "copyCodeButton": "Copy Code",
    "copiedButton": "Copied!"
}

keys_es = {
    "createClanTitle": "CREAR CLAN",
    "joinClanTitle": "UNIRSE A UN CLAN",
    "editClanNamePassword": "Editar Nombre/Contraseña",
    "deleteClan": "Eliminar Clan",
    "createClanDescription": "¡Crea un grupo para tu empresa y compite contra tus compañeros!",
    "clanNameLabel": "Nombre del Clan",
    "clanNameHint": "Ej: EXS Técnicos MAD",
    "clanNameValidator": "El nombre debe tener más de 3 caracteres",
    "clanDescriptionLabel": "Descripción del Clan",
    "clanDescriptionHint": "Sobre el clan...",
    "clanPasswordLabel": "Contraseña del Clan",
    "clanPasswordHint": "Mínimo 4 caracteres",
    "clanPasswordValidator": "La contraseña debe tener al menos 4 caracteres",
    "createClanAdminNotice": "Como creador, tendrás el rol de ADMIN y podrás gestionar a todos los miembros.",
    "createClanButton": "CREAR GRUPO/CLAN",
    "joinClanDescription": "Entra con código de invitación o contraseña del clan.",
    "inviteCodeOptionalLabel": "Código de Invitación (opcional)",
    "inviteCodeHint": "Ej: SPARK-XK29",
    "clanPasswordJoinHint": "Introduce la contraseña del grupo",
    "joinPasswordValidator": "Introduce la contraseña o el código",
    "joinClanButton": "UNIRSE AL GRUPO",
    "clanNotFound": "Clan no encontrado.",
    "clanMembersCount": "{count, plural, =0{Sin miembros} =1{1 miembro} other{{count} miembros}}",
    "maxLevel": "MÁXIMO",
    "currentLeague": "Liga Actual",
    "globalRank": "Rango Global",
    "membersListTitle": "MIEMBROS",
    "clanChatTitle": "CHAT DEL CLAN",
    "chatSilent": "El chat está silencioso...",
    "beFirstToInteract": "¡Sé el primero en interactuar!",
    "typeAMessage": "Escribe un mensaje...",
    "clanMascot": "Icono del Clan",
    "weeklyQuestsTitle": "MISIONES SEMANALES",
    "noActiveQuests": "Sin misiones activas.",
    "joinRequestsTitle": "SOLICITUDES DE INGRESO",
    "noPendingRequests": "No hay solicitudes pendientes por ahora.",
    "unknownMember": "Miembro Desconocido",
    "acceptJoinRequestSuccess": "¡Solicitud aceptada!",
    "rejectJoinRequestSuccess": "¡Solicitud rechazada!",
    "clanCreatedSuccess": "¡Clan creado con éxito!",
    "errorCreatingClan": "Error al crear: ",
    "joinRequestSent": "¡Solicitud de ingreso enviada! Espera la aprobación.",
    "joinedClanSuccess": "¡Te has unido al clan!",
    "errorJoiningClan": "Error al unirse: ",
    "editClanTitle": "Editar Clan",
    "newClanNameHint": "Nuevo nombre del clan",
    "mainColorLabel": "COLOR PRINCIPAL",
    "clanIconLabel": "ICONO DEL CLAN",
    "cancelButton": "Cancelar",
    "saveButton": "GUARDAR",
    "clanUpdatedSuccess": "¡Clan actualizado con éxito!",
    "errorUpdatingClan": "Error al actualizar clan: ",
    "deleteClanDialogTitle": "¿Eliminar Clan?",
    "deleteClanWarning": "¡Esta acción es permanente! Todos los miembros serán eliminados.",
    "deleteClanButton": "ELIMINAR",
    "clanDeletedSuccess": "¡Clan eliminado con éxito!",
    "errorDeletingClan": "Error al eliminar: ",
    "clanLeaguesTitle": "Ligas del Clan",
    "closeButton": "Cerrar",
    "inviteToClanTitle": "Invitar al Clan",
    "shareCodeSubtitle": "Comparte el código de abajo",
    "inviteCodeInfo": "Cualquier persona con este código puede unirse a tu clan.",
    "codeCopied": "¡Código copiado!",
    "tapToCopy": "Toca el código para copiar",
    "copyCodeButton": "Copiar Código",
    "copiedButton": "¡Copiado!"
}

# Ensure keys exist in _pt for placeholders
keys_pt_meta = {"@clanMembersCount": {"placeholders": {"count": { "type": "int" }}}}

add_keys(keys_pt, keys_en, keys_es)
# add metadata separately
with open('lib/l10n/app_pt.arb', 'r', encoding='utf-8') as f: data_pt = json.load(f)
for k, v in keys_pt_meta.items(): data_pt[k] = v
with open('lib/l10n/app_pt.arb', 'w', encoding='utf-8') as f: json.dump(data_pt, f, indent=2, ensure_ascii=False)

replacements = [
    ("'CRIAR CLÃ'", "AppLocalizations.of(context)!.createClanTitle"),
    ("'ENTRAR EM UM CLÃ'", "AppLocalizations.of(context)!.joinClanTitle"),
    ("'Editar Nome/Senha'", "AppLocalizations.of(context)!.editClanNamePassword"),
    ("'Deletar Clã'", "AppLocalizations.of(context)!.deleteClan"),
    ("'Crie um grupo para sua empresa e compete contra seus colegas!'", "AppLocalizations.of(context)!.createClanDescription"),
    ("'Nome do Clã'", "AppLocalizations.of(context)!.clanNameLabel"),
    ("'Ex: EXS Técnicos SP'", "AppLocalizations.of(context)!.clanNameHint"),
    ("'Nome deve ter mais que 3 caracteres'", "AppLocalizations.of(context)!.clanNameValidator"),
    ("'Descrição do Clã'", "AppLocalizations.of(context)!.clanDescriptionLabel"),
    ("'Sobre o clã...'", "AppLocalizations.of(context)!.clanDescriptionHint"),
    ("'Senha do Clã'", "AppLocalizations.of(context)!.clanPasswordLabel"),
    ("'Mínimo 4 caracteres'", "AppLocalizations.of(context)!.clanPasswordHint"),
    ("'Senha deve ter pelo menos 4 caracteres'", "AppLocalizations.of(context)!.clanPasswordValidator"),
    ("'Como criador, você terá o cargo de ADMIN e poderá gerenciar todos os membros.'", "AppLocalizations.of(context)!.createClanAdminNotice"),
    ("'CRIAR GRUPO/CLÃ'", "AppLocalizations.of(context)!.createClanButton"),
    ("'Entre com código de convite ou com a senha do clã.'", "AppLocalizations.of(context)!.joinClanDescription"),
    ("'Código de Convite (opcional)'", "AppLocalizations.of(context)!.inviteCodeOptionalLabel"),
    ("'Ex: SPARK-XK29'", "AppLocalizations.of(context)!.inviteCodeHint"),
    ("'Digite a senha do grupo'", "AppLocalizations.of(context)!.clanPasswordJoinHint"),
    ("'Informe a senha ou o código'", "AppLocalizations.of(context)!.joinPasswordValidator"),
    ("'ENTRAR NO GRUPO'", "AppLocalizations.of(context)!.joinClanButton"),
    ("'Clã não encontrado.'", "AppLocalizations.of(context)!.clanNotFound"),
    ("Text('\\$memberCount membros'", "Text(AppLocalizations.of(context)!.clanMembersCount(memberCount)"),
    ("'MÁXIMO'", "AppLocalizations.of(context)!.maxLevel"),
    ("'Liga Atual'", "AppLocalizations.of(context)!.currentLeague"),
    ("'Rank Global'", "AppLocalizations.of(context)!.globalRank"),
    ("'MEMBROS'", "AppLocalizations.of(context)!.membersListTitle"),
    ("'CHAT DO CLÃ'", "AppLocalizations.of(context)!.clanChatTitle"),
    ("'O chat está silencioso...'", "AppLocalizations.of(context)!.chatSilent"),
    ("'Seja o primeiro a interagir!'", "AppLocalizations.of(context)!.beFirstToInteract"),
    ("'Digite uma mensagem...'", "AppLocalizations.of(context)!.typeAMessage"),
    ("'MISSÕES DA SEMANA'", "AppLocalizations.of(context)!.weeklyQuestsTitle"),
    ("'Nenhuma missão ativa.'", "AppLocalizations.of(context)!.noActiveQuests"),
    ("'PEDIDOS DE ENTRADA'", "AppLocalizations.of(context)!.joinRequestsTitle"),
    ("'Nenhum pedido pendente por enquanto.'", "AppLocalizations.of(context)!.noPendingRequests"),
    ("'Membro Desconhecido'", "AppLocalizations.of(context)!.unknownMember"),
    ("'Pedido aceito!'", "AppLocalizations.of(context)!.acceptJoinRequestSuccess"),
    ("'Pedido recusado!'", "AppLocalizations.of(context)!.rejectJoinRequestSuccess"),
    ("'Clã \"\\$_clanName\" criado com sucesso!'", "AppLocalizations.of(context)!.clanCreatedSuccess.replaceFirst('{clan}', _clanName)"), # Assuming we don't parameterize perfectly here to save time
    ("'Erro ao criar: \\$e'", "AppLocalizations.of(context)!.errorCreatingClan + e.toString()"),
    ("'Pedido de entrada enviado! Aguarde aprovação.'", "AppLocalizations.of(context)!.joinRequestSent"),
    ("'Você entrou no clã!'", "AppLocalizations.of(context)!.joinedClanSuccess"),
    ("'Erro ao entrar: \\${e.toString().replaceFirst(\\'Exception: \\', \\'\\')}'", "AppLocalizations.of(context)!.errorJoiningClan + e.toString().replaceFirst('Exception: ', '')"),
    ("'Editar Clã'", "AppLocalizations.of(context)!.editClanTitle"),
    ("'Novo nome do clã'", "AppLocalizations.of(context)!.newClanNameHint"),
    ("'COR PRINCIPAL'", "AppLocalizations.of(context)!.mainColorLabel"),
    ("'ÍCONE DO CLÃ'", "AppLocalizations.of(context)!.clanIconLabel"),
    ("'Cancelar'", "AppLocalizations.of(context)!.cancelButton"),
    ("'SALVAR'", "AppLocalizations.of(context)!.saveButton"),
    ("'Clã atualizado com sucesso!'", "AppLocalizations.of(context)!.clanUpdatedSuccess"),
    ("'Erro ao atualizar clã: \\$e'", "AppLocalizations.of(context)!.errorUpdatingClan + e.toString()"),
    ("'Deletar Clã?'", "AppLocalizations.of(context)!.deleteClanDialogTitle"),
    ("'Esta ação é permanente! Todos os membros serão removidos.'", "AppLocalizations.of(context)!.deleteClanWarning"),
    ("'DELETAR'", "AppLocalizations.of(context)!.deleteClanButton"),
    ("'Clã deletado com sucesso!'", "AppLocalizations.of(context)!.clanDeletedSuccess"),
    ("'Erro ao deletar: \\$e'", "AppLocalizations.of(context)!.errorDeletingClan + e.toString()"),
    ("'Ligas do Clã'", "AppLocalizations.of(context)!.clanLeaguesTitle"),
    ("'Fechar'", "AppLocalizations.of(context)!.closeButton"),
    ("'Convidar para o Clã'", "AppLocalizations.of(context)!.inviteToClanTitle"),
    ("'Compartilhe o código abaixo'", "AppLocalizations.of(context)!.shareCodeSubtitle"),
    ("'Qualquer pessoa com este código pode entrar no seu clã.'", "AppLocalizations.of(context)!.inviteCodeInfo"),
    ("'Código copiado!'", "AppLocalizations.of(context)!.codeCopied"),
    ("'Toque no código para copiar'", "AppLocalizations.of(context)!.tapToCopy"),
    ("'Copiar Código'", "AppLocalizations.of(context)!.copyCodeButton"),
    ("'Copiado!'", "AppLocalizations.of(context)!.copiedButton")
]

# We need to manually fix clanCreatedSuccess
keys_pt["clanCreatedSuccess"] = "Clã criado com sucesso!"
keys_en["clanCreatedSuccess"] = "Clan successfully created!"
keys_es["clanCreatedSuccess"] = "¡Clan creado con éxito!"

replace_in_file('lib/screens/clan_screen.dart', replacements)
print("Updated clan_screen.dart")

