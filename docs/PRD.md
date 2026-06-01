# PRD — SPARK: Micro-learning Gamificado para Engenharia
**Versão:** 2.1 (Atualizado pós-pull — Maio 2026)
**Autor:** Análise comparativa gerada via Claude Code
**Status:** Documento vivo — revisão recomendada a cada ciclo

---

> Este documento registra dois estados do produto em paralelo:
> - **[VISÃO]** — o que foi planejado no PRD original
> - **[ATUAL]** — o que existe implementado no código hoje

---

## 1. Visão Geral

**[VISÃO]**
SPARK como plataforma de micro-learning standalone para o setor elétrico e industrial (Proteção e Controle). Inspirado no Duolingo, com lições de 5 minutos, modo offline e recompensas financeiras via ecossistema GPECx. Frase-chave: *"Onde o conhecimento técnico se transforma em ativo financeiro."*

**[ATUAL]**
SPARK é uma plataforma de e-learning gamificada em Flutter, com foco atual em normas de segurança do trabalho brasileiras (NR-10, NR-35). O escopo de P&C (IEC 61850) ainda não está no conteúdo, mas a infraestrutura para inserção está pronta — o admin panel foi implementado com suporte a import via JSON. The Vault (diferencial econômico) ainda não está ativo. O produto possui gamificação rica (streaks, badges, duelos, clãs, missões diárias/semanais, leaderboard), rastreamento analítico via Firebase Analytics, notificações push via FCM e resiliência de conexão via fila offline (Hive).

**Gap principal:** Conteúdo de nicho (P&C / IEC 61850) ausente. The Vault não implementado. Design Stitch (UI dinâmica por nível) pendente.

---

## 2. O Problema (The Gap)

**[VISÃO]**
| Problema | Descrição |
|---|---|
| Baixa Retenção | Treinamentos técnicos são exaustivos e teóricos |
| Falta de Conectividade | Profissionais em campo não têm sinal |
| Falta de Incentivo | Estudar normas é obrigação, não investimento |

**[ATUAL]**
Os problemas de retenção e incentivo estão bem endereçados — gamificação implementada com streaks, badges, duelos ELO, missões diárias/semanais, leaderboard e clãs. O `analytics_service.dart` instrumenta os principais eventos para monitorar retenção.

O problema de conectividade foi **redefinido**: Antigravity (offline-first completo) foi descartado, mas o produto implementa **resiliência de conexão** — se a internet cair durante uma sessão ativa, o progresso da lição é enfileirado localmente (Hive) e sincronizado automaticamente ao reconectar. O app exige internet para iniciar, mas não perde dados por oscilações de rede.

**Decisão registrada (Mai/2026):** Offline-first descartado. Resiliência de conexão mantida intencionalmente via `offline_sync_service.dart`.

---

## 3. Público-Alvo

**[VISÃO]**
- **Primário:** Engenheiros e técnicos de P&C (Proteção, Controle e Automação)
- **Secundário:** Estudantes e recém-formados da área industrial
- **B2B:** Empresas que buscam capacitação contínua e mensurável para equipes

**[ATUAL]**
O app não segmenta o público explicitamente no produto. As trilhas disponíveis cobrem NR-10 e NR-35 (normas de segurança geral), não conteúdo específico de P&C. Não há features B2B (painéis de gestão, relatórios de equipe, anonimização LGPD).

**Gap:** Conteúdo de P&C/IEC 61850 ausente. Features B2B (painel corporativo, relatórios) inexistentes.

---

## 4. Pilares Estratégicos

### 4.1 Independência Total (Standalone)

**[VISÃO]** Produto independente do GPECx Flow, mas integrado ao ecossistema via The Vault.

**[ATUAL]** O app é tecnicamente standalone (Firebase próprio, projeto `spark-v1-e0eb5`). Não há integração com GPECx Flow. Também não há integração com o ecossistema de recompensas (Vault/LEELO/VETO). **Pilar atendido parcialmente** — é standalone, mas isolado do ecossistema.

---

### 4.2 Design Stitch (UI Evolutiva por Nível)

**[VISÃO]** A interface deve mudar visualmente conforme o nível do usuário:
- BT: Cores azuladas, luz suave
- MT: Tons esverdeados/cian
- AT: Laranjas e âmbar
- EAT: Vermelho neon + partículas de alta energia
- Efeito Glitch em erros de quiz

**[ATUAL]**
- Existe um tema único dark/cyberpunk definido em `lib/theme/app_theme.dart`
- Os níveis BT/MT/AT/EAT existem no modelo de dados (`tensionLevel` no `UserModel`)
- Existem widgets de partícula (`spark_emitter.dart`, `streak_lightning_emitter.dart`)
- O fundo de circuito PCB (`pcb_background.dart`) reforça a estética técnica
- **O tema NÃO muda dinamicamente conforme o nível** — é um tema estático único
- Efeito glitch não foi identificado

**Gap:** Stitch não implementado como sistema dinâmico. A UI não responde ao `tensionLevel` do usuário.

---

### 4.3 Antigravity — Redefinido: Resiliência de Conexão ✅

**[VISÃO ORIGINAL]** Offline-first completo: app funcional sem internet, sync posterior.

**[DECISÃO — Mai/2026]** Duas definições distintas, com decisões opostas:

| Conceito | Definição | Decisão |
|---|---|---|
| **Offline-first** | App funciona sem internet desde o início da sessão | ❌ Descartado |
| **Resiliência de conexão** | App exige internet para iniciar, mas não perde progresso se a conexão oscilar durante a sessão | ✅ Implementado |

**Implementação atual (`offline_sync_service.dart`):**
- O app exige conexão para abrir e navegar
- Se a conexão cair durante um quiz, a conclusão da lição é enfileirada localmente via Hive
- Quando a conexão é restaurada, a fila é sincronizada automaticamente com o Firestore
- O usuário não percebe a interrupção — o progresso nunca é perdido por oscilação de rede

**Por que manter:** O público-alvo (engenheiros em ambientes industriais) frequentemente enfrenta redes móveis instáveis. Perder o progresso de uma lição por 30 segundos sem sinal destruiria a retenção — o KPI mais crítico do produto.

---

### 4.4 The Vault (Economia Real)

**[VISÃO]**
- SparkPoints conversíveis em vouchers (LEELO, VETO, Power Play)
- Tabela de conversão: 1000 SP = R$ 100,00 (exemplo)
- Geração de código hash único: `uid + timestamp + SP_amount`
- Validação anti-fraude via Firestore antes de emitir voucher
- Integração com APIs externas (LEELO, VETO)

**[ATUAL]**
- `sparkPoints` existe no modelo de dados e é atribuído ao usuário
- Existe `store_screen.dart` (tela de loja) mas sem implementação de conversão real
- Não existe lógica de geração de voucher, hash ou integração com APIs externas
- `transactions/{txId}` existe na estrutura do Firestore mas sem uso de voucher

**Gap:** The Vault é a feature mais diferenciadora do produto e está completamente ausente.

---

## 5. Requisitos Funcionais — Estado Atual

### 5.1 Trilhas e Lições

| Feature | Planejado | Implementado | Status |
|---|---|---|---|
| Lições curtas (~5 min) | ✅ | ✅ (conteúdo em `data/`) | Parcial — conteúdo limitado |
| Offline-first completo | ✅ | ~~Descartado~~ | Decisão: online com resiliência |
| Resiliência de conexão | — | ✅ `offline_sync_service.dart` | Implementado (Hive + auto-sync) |
| IA generativa via API | ✅ | ~~Descartado~~ | Substituído: NotebookLM offline |
| Validação SME | ✅ | ✅ (review manual no NotebookLM) | Processo definido |
| Conteúdo P&C / IEC 61850 | ✅ | ❌ | Bloqueado por falta de conteúdo |
| Múltiplos tipos de questão | ✅ | ✅ (múltipla escolha, V/F, lacuna) | Implementado |
| Upload de questões via JSON (admin) | ❌ (não previsto) | ✅ `admin_controller.importFromJSON()` | Implementado |
| Admin panel CRUD completo | ❌ (não previsto) | ✅ `lib/core/admin/` | Implementado |

### 5.1.1 Estratégia de Conteúdo — Decisão Mai/2026

A geração de conteúdo técnico segue o fluxo abaixo, **sem integração de API com ferramentas externas**:

```
1. Especialista usa NotebookLM (uso único, fora do app)
   → Sobe os documentos técnicos como fonte (IEC 61850, manuais, NRs)
   → Solicita geração de questões no formato JSON padronizado
   → Revisa e ajusta o conteúdo gerado

2. Administrador faz upload do arquivo JSON no painel admin do SPARK

3. Admin panel valida a estrutura e exibe preview

4. Administrador confirma → questões publicadas no Firestore

5. Para atualizar conteúdo: gera novo JSON, faz novo upload
```

**Motivação da decisão:**
- Zero custo recorrente de tokens
- Zero dependência de API externa em produção
- Conteúdo versionável — o arquivo JSON é a fonte da verdade
- Atualização de trilha = trocar o arquivo, sem tocar em código

### 5.2 Motor de Gamificação

| Feature | Planejado | Implementado | Status |
|---|---|---|---|
| Níveis de Tensão (BT/MT/AT/EAT) | ✅ | ✅ (`tensionLevel` + `level`) | Implementado |
| SparkPoints (SP) | ✅ | ✅ (`sparkPoints` no UserModel) | Implementado |
| Streaks diários | ✅ | ✅ (`currentStreak`, `longestStreak`) | Implementado |
| Badges por norma | ✅ | ✅ (10+ badges definidos) | Implementado |
| XP e progressão | ✅ | ✅ (`xp`, `weeklyXp`) | Implementado |
| Missão diária (3 lições → badge + 50 SP) | ❌ (não previsto) | ✅ `gamification_service.dart` | Além da visão |
| Desafio semanal (streak 7 dias → badge + 100 XP) | ❌ (não previsto) | ✅ `gamification_service.dart` | Além da visão |
| Duelos 1v1 com ELO | ❌ (não previsto) | ✅ `match_service.dart` | Além da visão |
| Clãs e chat | ❌ (não previsto) | ✅ `clan_service.dart` | Além da visão |
| Covenants (desafios semanais) | ❌ (não previsto) | ✅ `covenant_service.dart` | Além da visão |
| Leaderboard | ❌ (não previsto) | ✅ `leaderboard_screen.dart` | Além da visão |
| Log de auditoria de SP/XP | ❌ (não previsto) | ✅ `audit_service.dart` | Além da visão |
| Push notifications (FCM) | ❌ (não previsto) | ✅ `fcm_service.dart` | Além da visão |

### 5.3 The Vault (Recompensas)

| Feature | Planejado | Implementado | Status |
|---|---|---|---|
| Conversão SP → Voucher | ✅ | ❌ | Ausente |
| Hash anti-fraude | ✅ | ❌ | Ausente |
| Integração LEELO/VETO | ✅ | ❌ | Ausente |
| Tela de loja | ✅ | ✅ (estrutura) | Sem backend real |

---

## 6. Metas de Sucesso (KPIs)

**[VISÃO]**
| KPI | Meta |
|---|---|
| Streak médio | 5 dias |
| Conversão (vouchers gerados) | 15% dos usuários no M1 |
| Proficiência para subir nível | 80% de precisão |

**[ATUAL]**
- Streak: rastreado (`currentStreak`, `longestStreak`) + `analytics_service.logStreakUpdated()` — mensurável via Firebase Analytics
- Conversão de vouchers: **impossível medir** — The Vault não existe
- Proficiência: `bestScore` e `progressPercent` existem por módulo, mas a regra de 80% para evolução de nível não está implementada — o nível sobe por XP, não por precisão

**Instrumentação disponível (analytics_service.dart):**
| Evento | Método |
|---|---|
| Lição concluída | `logLessonCompleted()` — time_spent, score, xp, sp |
| Subida de nível | `logLevelUp()` — old_level, new_level, total_xp |
| Badge desbloqueado | `logBadgeUnlocked()` |
| Missão diária concluída | `logDailyMissionCompleted()` |
| Streak atualizado | `logStreakUpdated()` |
| Login / Cadastro | `logLogin()`, `logSignUp()` |

**Gap parcialmente fechado:** Streak e engajamento já são mensuráveis. KPIs de voucher ainda bloqueados pelo Vault ausente.

---

## 7. Roadmap Macro — Estado Real

**[VISÃO]**
| Mês | Marco |
|---|---|
| M1 | Alpha Técnico (20 Power Users) + Validação de IA |
| M2 | Beta Aberto + Ativação do Vault (Vouchers) |
| M3 | Lançamento Público (App Store/Play Store) |

**[ATUAL]**
O produto está em **desenvolvimento ativo** (v1.0.0), com CI/CD configurado para deploy web via GCP Cloud Run. Não há evidência de fases Alpha/Beta formalizadas ou de usuários piloto ativos no código. O Vault (M2) não iniciou. O lançamento em App Store/Play Store (M3) ainda não ocorreu — o deploy atual é web.

---

## 8. Features Implementadas Além da Visão Original

| Feature | Descrição | Valor |
|---|---|---|
| Duelos 1v1 (ELO) | Quiz competitivo com matchmaking e ranking ELO | Alto — retenção por competição |
| Clãs + Chat | Grupos de estudo com mensagens em tempo real | Alto — retenção social |
| Covenants | Desafios semanais com objetivos e recompensas | Alto — hábito semanal |
| Leaderboard | Ranking global e por período | Médio — competição visível |
| Missões diárias/semanais | 3 lições/dia → recompensa; streak 7 dias → recompensa | Alto — hábito diário |
| Admin panel | CRUD completo + import JSON para gestão de conteúdo | Crítico — operação do produto |
| Firebase Analytics | Rastreamento de eventos de aprendizado e gamificação | Alto — decisão de produto baseada em dados |
| Audit log | Histórico completo de SP/XP por usuário | Médio — anti-fraude e suporte |
| Push Notifications (FCM) | Notificações para engajamento e retenção | Alto — reativação de usuários inativos |
| Resiliência de conexão | Fila local (Hive) + auto-sync ao reconectar | Alto — proteção de progresso em redes instáveis |

---

## 9. Considerações Legais (LGPD)

**[VISÃO]**
- Dados de desempenho para personalização e recompensas
- Anonimização para relatórios B2B
- SparkPoints como "créditos de incentivo" (sem valor monetário em espécie)

**[ATUAL]**
- Firestore Security Rules implementadas com controle por `uid`
- Não existe mecanismo de anonimização
- Feature de relatórios B2B inexistente
- A natureza jurídica dos SparkPoints não está definida no produto

---

## 10. Resumo dos Gaps Ativos

| Prioridade | Gap | Impacto |
|---|---|---|
| 🔴 Alta | The Vault (conversão SP→voucher) | Principal diferencial de negócio ausente |
| 🔴 Alta | Proteção de rota `/admin` (sem verificação de role) | Qualquer usuário pode acessar o admin panel |
| 🟡 Média | Conteúdo P&C / IEC 61850 | Identidade de nicho não refletida no produto |
| 🟡 Média | Design Stitch dinâmico | UI não evolui com o nível do usuário |
| 🟡 Média | Alinhamento de `difficulty` no JSON (BT/MT vs easy/medium) | Admin e import usam valores diferentes |
| 🟢 Baixa | Features B2B (painel corporativo) | Mercado secundário não endereçado |

**Fechados neste ciclo:**
| Item | Status |
|---|---|
| Admin panel com upload JSON | ✅ Implementado — `lib/core/admin/` |
| Instrumentação de KPIs | ✅ Implementado — `analytics_service.dart` |
| Auditoria de SP/XP | ✅ Implementado — `audit_service.dart` |
| Push notifications | ✅ Implementado — `fcm_service.dart` |
| Resiliência de conexão | ✅ Implementado — `offline_sync_service.dart` |

**Descartados intencionalmente:**
| Item | Decisão |
|---|---|
| Offline-first (Antigravity) | Removido — produto é online com resiliência de conexão |
| IA Generativa via API | Removido — substituído por NotebookLM offline + upload JSON |
