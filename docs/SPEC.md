# SPEC — SPARK: Arquitetura Técnica e Engenharia
**Versão:** 2.1 (Atualizado pós-pull — Maio 2026)
**Autor:** Análise comparativa gerada via Claude Code
**Status:** Documento vivo — revisão recomendada a cada ciclo

---

> Este documento registra dois estados técnicos em paralelo:
> - **[SPEC ORIGINAL]** — o que foi especificado
> - **[ATUAL]** — o que está implementado no código hoje

---

## 1. Stack Tecnológica

| Camada | Spec Original | Atual | Status |
|---|---|---|---|
| Framework | Flutter (Mobile) | Flutter (Web + Mobile) | ✅ + Além |
| Linguagem | Dart 3.x | Dart 3.11.1+ | ✅ |
| State Management | BLoC ou Riverpod | Riverpod 3.3.1 | ✅ |
| Local Storage (offline-first) | SQLite (`sqflite`) | ~~Descartado~~ | Decisão: online com resiliência |
| Local Storage (resiliência) | — | Hive (`hive_flutter`) | ✅ Adicionado — fila de sync |
| Detecção de rede | — | `connectivity_plus` | ✅ Adicionado — usado pelo OfflineSyncService |
| Backend | Firebase (Firestore, Auth, Functions) | Firebase (Auth, Firestore, Storage, Crashlytics, Analytics) | ✅ + Analytics |
| Push Notifications | — | Firebase Cloud Messaging (FCM) | ✅ Adicionado |
| AI | Vertex AI (via API) | ~~Descartado~~ | Decisão: NotebookLM offline + upload JSON |
| Architecture | Clean Architecture | Funcional (models/services/providers/screens) + Clean em `/core/admin` | Parcial |
| Roteamento | — | GoRouter 17.1.0 | Adicionado |
| Deploy | Mobile (App Store/Play Store) | GCP Cloud Run (web) + Docker + Nginx | Diferente |
| CI/CD | — | GitHub Actions (Dart analyze + GCP deploy) | Adicionado |

### Observações

**Sobre o Deploy:** A spec original focava em mobile nativo. O deploy atual é uma Flutter Web build servida via Nginx no Cloud Run. Isso permite validação rápida, mas push notifications via FCM têm suporte limitado em Flutter Web comparado ao mobile nativo.

**Sobre Arquitetura:** O módulo `/core/admin` segue Clean Architecture formal (domain/data/presentation). O restante do app usa separação funcional pragmática. Essa inconsistência não é um problema agora, mas deve ser considerada ao expandir.

**Sobre a Arquitetura:** A spec especificava Clean Architecture. O projeto usa uma separação funcional (`models/`, `services/`, `providers/`, `screens/`) que é pragmática e funciona, mas não implementa as camadas formais (Domain, Data, Presentation com Repositories e UseCases). Isso não é necessariamente um problema, mas deve ser uma decisão consciente.

---

## 2. Modelagem de Dados

### 2.1 User Profile

**[SPEC ORIGINAL]**
```json
{
  "uid": "string",
  "name": "string",
  "level": "enum [BT, MT, AT, EAT]",
  "voltage_points": "int",
  "spark_points": "int",
  "streak_count": "int",
  "last_sync": "timestamp",
  "badges": ["string"]
}
```

**[ATUAL]** — `lib/models/user_model.dart` + Firestore `users/{uid}`
```json
{
  "uid": "string",
  "displayName": "string",
  "email": "string",
  "photoUrl": "string",
  "role": "string",
  "xp": "int",
  "level": "int (numérico, não enum)",
  "tensionLevel": "string [BT, MT, AT, EAT]",
  "sparkPoints": "int",
  "currentStreak": "int",
  "longestStreak": "int",
  "activeDays": "int",
  "studiedToday": "bool",
  "lastStudyDate": "timestamp",
  "weeklyXp": "int",
  "unlockedBadgeIds": ["string"],
  "clanId": "string",
  "clanName": "string",
  "eloRating": "int",
  "wins": "int",
  "losses": "int",
  "lastOnline": "timestamp"
}
```

**Diferenças notáveis:**
- `level` na spec era enum string (BT/MT/AT/EAT). Na implementação existem dois campos: `level` (int numérico) e `tensionLevel` (string enum). **Débito ativo** — risco de divergência.
- `voltage_points` da spec virou `xp`. XP é ganho por atividades; a proficiência real é rastreada por `bestScore` em `ProgressModel`.
- Campos sociais adicionados: `clanId`, `clanName`, `eloRating`, `wins`, `losses`.
- `fcmToken` adicionado — salvo pelo `FcmService` após login para push notifications.
- `last_sync` não existe — offline-first descartado; resiliência usa Hive externamente, não o modelo de usuário.

---

### 2.2 Lessons & Quizzes

**[SPEC ORIGINAL]**
```json
{
  "id": "string",
  "module": "string",
  "title": "string",
  "content": "markdown",
  "questions": [
    {
      "type": "multiple_choice",
      "question": "string",
      "options": ["string"],
      "answer_index": "int",
      "explanation": "string"
    }
  ]
}
```

**[ATUAL]** — `lib/models/quiz_models.dart` + Firestore `categories/{catId}/modules/{modId}/lessons/{lessonId}`

**Estrutura no Firestore:**
```
categories/{catId}
  └── modules/{modId}
        └── lessons/{lessonId}
              └── questions/{questionId}
```

**Modelo de Questão (implementado):**
```dart
// Múltipla Escolha
{
  "statement": "string",
  "options": ["string"],
  "correctIndex": "int",
  "explanation": "string",
  "type": "multiple_choice"
}

// Verdadeiro ou Falso
{
  "statement": "string",
  "isTrue": "bool",
  "explanation": "string",
  "type": "true_false"
}

// Preencher lacuna
{
  "statement": "string (com ___)",
  "answer": "string",
  "options": ["string"],
  "explanation": "string",
  "type": "fill_blank"
}
```

**Diferenças notáveis:**
- A spec previa `content: markdown` para o corpo da lição (texto explicativo). No modelo atual, a lição é quase inteiramente quiz-driven — não há campo de conteúdo rico por lição.
- A hierarquia é mais profunda: `category > module > lesson > question` (4 níveis vs. 2 na spec).
- Conteúdo estático também existe hardcoded em `lib/data/` (bloco01_mod01_data.dart etc.), separado do Firestore.

---

### 2.3 Modelos Adicionais (não previstos na spec)

**ProgressModel** — `lib/models/progress_model.dart`
```json
{
  "moduleId": "string",
  "categoryId": "string",
  "moduleName": "string",
  "completedLessons": "int",
  "progressPercent": "double",
  "isCompleted": "bool",
  "startedAt": "timestamp",
  "completedAt": "timestamp",
  "bestScore": "double",
  "attempts": "int"
}
```

**CovenantModel** — `lib/models/covenant_model.dart`
```json
{
  "covenantId": "string",
  "currentProgress": "int",
  "maxProgress": "int",
  "isCompleted": "bool",
  "trackingType": "string",
  "weekKey": "string"
}
```

**MatchModel** — `lib/models/match_models.dart`
```json
{
  "matchId": "string",
  "player1Id": "string",
  "player2Id": "string",
  "questions": ["QuizQuestion"],
  "player1Score": "int",
  "player2Score": "int",
  "status": "enum [waiting, active, finished]",
  "winnerId": "string"
}
```

**BadgeData** — `lib/models/badge_model.dart`
```json
{
  "id": "string",
  "name": "string",
  "emoji": "string",
  "description": "string",
  "criteria": "string"
}
```

---

## 3. Pilares Técnicos

### 3.1 Antigravity — Redefinido: Resiliência de Conexão ✅

**[SPEC ORIGINAL]** Offline-first completo com SQLite e WorkManager.

**[DECISÃO — Mai/2026]** Offline-first descartado. **Resiliência de conexão implementada** via `offline_sync_service.dart`.

```
Modelo atual (intencional):
├── App exige internet para iniciar e navegar (online-only)
├── Se conexão cair durante quiz → operação enfileirada no Hive
├── Ao reconectar → fila sincronizada automaticamente com Firestore
└── Usuário nunca perde progresso por oscilação de rede
```

**Implementação técnica:**
```
offline_sync_service.dart:
├── Storage: Hive boxes
│   ├── 'offline_queue' — fila de operações pendentes
│   └── 'user_cache'   — snapshot local do usuário
├── Conectividade: connectivity_plus (listener em tempo real)
├── Operação suportada: 'mark_lesson'
│   └── Campos: uid, catId, modId, lessonId, xpEarned, spEarned
├── Flush automático: _flushQueue() ao reconectar
└── Integração: inicializado em main.dart, delegado por progress_service.dart
```

**O que NÃO faz (limites intencionais):**
- Não permite abrir o app sem internet
- Não faz cache de lições para navegação offline
- Não sincroniza dados sociais (clãs, duelos) offline

---

### 3.2 Stitch (Design System Evolutivo)

**[SPEC ORIGINAL]**
```
Regras de tema por tensionLevel:
├── BT: Cores azuladas, luz suave
├── MT: Tons esverdeados/cian
├── AT: Laranjas e âmbar
├── EAT: Vermelho neon + partículas
└── Efeito glitch em erro de quiz
```

**[ATUAL]** — `lib/theme/app_theme.dart`
```dart
// Tema único estático — dark cyberpunk
static const Color primaryCyan = Color(0xFF00E5FF);
static const Color primaryPurple = Color(0xFF7B2FBE);
static const Color neonGreen = Color(0xFF39FF14);
static const Color electricBlue = Color(0xFF0080FF);
static const Color warningYellow = Color(0xFFFFD600);
// ... etc.
```

- O `tensionLevel` existe no `UserModel` mas não é consumido pelo tema
- `spark_emitter.dart` e `streak_lightning_emitter.dart` existem como widgets de partícula mas são estáticos
- Não há `ThemeExtension` ou provider de tema que reaja ao nível do usuário
- Efeito glitch não identificado

**O que precisaria ser feito:**
1. Criar `AppThemeProvider` (Riverpod) que observa `user.tensionLevel`
2. Definir `ThemeData` para cada nível (BT/MT/AT/EAT) com paletas distintas
3. Aplicar animação de transição ao mudar de nível
4. Implementar widget de efeito glitch para feedback de erro

---

### 3.3 The Vault (Segurança e Vouchers)

**[SPEC ORIGINAL]**
```
Fluxo de geração de voucher:
1. Usuário solicita conversão de SP
2. Função local gera hash: uid + timestamp + SP_amount
3. Firestore valida que o usuário possuía os SP (anti-fraude)
4. SP deduzidos localmente → marcados como "pendente de sync"
5. Voucher emitido e integrado com API externa (LEELO, VETO)
```

**[ATUAL]**
- `sparkPoints` existe e é gerenciado em `user_service.dart`
- `store_screen.dart` existe como tela mas não tem lógica de conversão
- `transactions/{txId}` existe no Firestore como subcoleção mas sem uso real
- Nenhuma Cloud Function de vault foi identificada
- Sem integração com APIs externas

**O que precisaria ser feito:**
1. Cloud Function `POST /v1/vault/redeem` com lógica de:
   - Verificar saldo de SP do usuário
   - Deduzir SP com transação atômica Firestore
   - Gerar código voucher (hash seguro)
   - Registrar em `transactions/` com status
2. Integração com APIs dos parceiros (LEELO, VETO) via webhooks ou REST
3. Tela de histórico de resgates
4. Regras Firestore para proteger `transactions/` de escrita direta pelo client

---

### 3.4 Admin Panel — Gestão de Conteúdo ✅

Implementado em `lib/core/admin/` seguindo Clean Architecture:

```
admin/
├── domain/admin_repository.dart          → interface abstrata
├── data/admin_repository_impl.dart       → CRUD Firestore
└── presentation/
    ├── admin_controller.dart             → estado Riverpod (NotifierProvider)
    ├── admin_dashboard_page.dart         → layout principal (sidebar + painel)
    └── widgets/
        ├── admin_content_panel.dart      → árvore trilha > lições > questões
        ├── admin_entity_form.dart        → form reutilizável
        ├── admin_dialogs_new.dart        → dialogs de criação + import JSON
        ├── admin_trail_wizard_dialog.dart → gerador de trilha completa
        ├── admin_entity_list_view.dart   → listagem com seleção
        └── admin_cards.dart             → cards de overview
```

**Features implementadas:**
- CRUD completo: categorias → módulos → trilhas → lições → questões
- Import via JSON: `AdminController.importFromJSON()` — busca/cria categoria e módulo, sempre cria trilha nova, commit atômico via batch
- Trail Wizard: gera estrutura completa com N lições + M avaliações automaticamente
- Streams em tempo real do Firestore

**Gap de segurança crítico:** Nenhuma verificação de role na rota `/admin`. Qualquer usuário autenticado pode acessar. Necessário implementar guard de rota verificando `user.role == 'admin'` antes de produção.

**Inconsistência de schema a corrigir:** O admin internamente usa `difficulty: "easy|medium|hard"`. O schema de import JSON definido nesta SPEC usa `"BT|MT|AT|EAT"`. Precisam ser alinhados.

---

### 3.5 Serviços de Suporte — Implementados no Ciclo Atual

#### GamificationService (`lib/services/gamification_service.dart`)
- **Missão diária:** 3 lições concluídas no dia → badge `daily_warrior` + 50 SP
- **Desafio semanal:** streak ≥ 7 dias → badge `weekly_warrior` + 100 XP
- Documentos de missão salvos em `users/{uid}/missions/daily_{date}` e `weekly_{week}`
- Integrado em `progress_service.dart` — acionado automaticamente pós-lição

#### AnalyticsService (`lib/services/analytics_service.dart`)
- Firebase Analytics (GA4) — todos eventos em snake_case
- Eventos: `lesson_completed`, `level_up`, `badge_unlocked`, `daily_mission_done`, `weekly_mission_done`, `streak_updated`, `login`, `sign_up`
- User properties: `user_level`, `user_role` (segmentação)
- Suporte a opt-out: `setCollectionEnabled()` (LGPD)

#### AuditService (`lib/services/audit_service.dart`)
- Log imutável em `users/{uid}/audit_log`
- Registra: xpGained, spGained, spSpent, lessonCompleted, levelUp, badgeUnlocked, streakUpdated, dailyMissionCompleted, weeklyMissionCompleted, xpIntegrityFixed
- Falha silenciosa — não quebra o fluxo principal
- Fecha o gap de auditoria de SP identificado anteriormente

#### FcmService (`lib/services/fcm_service.dart`)
- Solicita permissão de notificação, obtém e persiste FCM token em `users/{uid}.fcmToken`
- Atualiza token automaticamente ao rotacionar
- Inicializado em `main.dart` antes do app carregar
- **Limitação:** Flutter Web tem suporte parcial a FCM — push em background não funciona em todos os browsers

---

## 4. Estrutura de API

**[SPEC ORIGINAL]**
```
POST /v1/user/sync       → delta de progresso offline
GET  /v1/lessons/fetch   → trilhas baseadas no perfil
POST /v1/vault/redeem    → SP → código de desconto
```

**[ATUAL]**
Não existe uma API REST própria. O app usa o Firebase SDK diretamente:
- `FirebaseFirestore.instance.collection(...).doc(...).get()` — leitura direta
- `FirebaseFirestore.instance.collection(...).doc(...).update()` — escrita direta
- Firebase Auth para autenticação

Não existe camada de API com versioning (`/v1/`). As Cloud Functions existentes (se houver) não foram identificadas no repositório — os `functions/` não estão no repo.

**Implicação:** A validação de regras de negócio críticas (como saldo de SP antes de emitir voucher) depende exclusivamente das Firestore Security Rules, não de lógica server-side.

---

## 5. Estratégia de Conteúdo — Decisão Mai/2026

**[SPEC ORIGINAL]**
```
Pipeline de geração de quizzes:
1. Ingestão de PDF (manual técnico)
2. RAG → Vertex AI → geração de questões
3. Human-in-the-Loop: SME valida e ajusta pesos no Alpha
4. Questões aprovadas publicadas no Firestore
```

**[DECISÃO — Mai/2026]**
Integração via API com ferramentas de IA **descartada**. A estratégia de conteúdo adotada é:

```
Geração (fora do app):
├── Ferramenta: NotebookLM (uso único por domínio)
├── Fontes: PDFs técnicos (IEC 61850, manuais de relé, NRs)
├── Saída: arquivo JSON padronizado
└── Revisão: especialista revisa antes de exportar

Publicação (dentro do app — admin panel):
├── Upload do arquivo JSON
├── Validação automática de schema
├── Preview das questões
└── Confirmação → Firestore
```

**Motivação:** Zero custo recorrente de tokens, zero dependência de API externa em produção, conteúdo versionável e auditável.

### Schema JSON de Importação

Formato obrigatório para upload via admin panel:

```json
{
  "category": "string — nome da categoria (ex: IEC 61850)",
  "module": "string — nome do módulo (ex: GOOSE Messaging)",
  "lesson": "string — nome da lição",
  "questions": [
    {
      "type": "multiple_choice",
      "statement": "string",
      "options": ["string", "string", "string", "string"],
      "correctIndex": 0,
      "explanation": "string",
      "difficulty": "BT | MT | AT | EAT"
    },
    {
      "type": "true_false",
      "statement": "string",
      "isTrue": true,
      "explanation": "string",
      "difficulty": "BT | MT | AT | EAT"
    },
    {
      "type": "fill_blank",
      "statement": "string com ___ indicando a lacuna",
      "answer": "string",
      "options": ["string", "string", "string", "string"],
      "explanation": "string",
      "difficulty": "BT | MT | AT | EAT"
    }
  ]
}
```

**Regras de validação no upload:**
- `category`, `module`, `lesson` obrigatórios
- `questions` deve ter ao menos 1 item
- `type` deve ser um dos três valores válidos
- `difficulty` deve ser `BT`, `MT`, `AT` ou `EAT`
- `correctIndex` deve ser índice válido dentro de `options`
- `options` obrigatório para `multiple_choice` e `fill_blank` (mínimo 2 itens)

### Prompt base para NotebookLM

Template a ser usado pelo especialista no NotebookLM para garantir o formato correto:

```
Com base nos documentos desta fonte, gere [N] questões sobre o tema "[TÓPICO]".
Siga exatamente este schema JSON. Use somente informações presentes nos documentos.
Distribua os tipos: múltipla escolha, verdadeiro/falso e preencher lacuna.
Atribua dificuldade conforme a complexidade: BT (básico), MT (intermediário), AT (avançado), EAT (especialista).
Retorne apenas o JSON, sem texto adicional.
```

---

## 6. Segurança

**[SPEC ORIGINAL]**
- Validação anti-fraude para geração de vouchers
- Pontos marcados como "pendente" até sync confirmado

**[ATUAL]** — `firestore.rules`

**Pontos positivos implementados:**
```javascript
// Usuário só acessa próprios dados
allow read, write: if request.auth.uid == userId;

// Role admin para criar/editar conteúdo
allow write: if isAdmin();

// Validação de tipo em campos críticos
allow update: if request.resource.data.xp is int
              && request.resource.data.sparkPoints is int;

// Controle de clã por role de membro/chief
allow delete: if isClanChief(clanId) || request.auth.uid == resource.data.uid;
```

**Gaps de segurança:**
- SparkPoints ainda podem ser incrementados pelo client sem validação server-side (Firestore Rules validam tipo, não lógica de negócio)
- Rota `/admin` sem guard de role — qualquer autenticado acessa o admin panel (**crítico**)
- Rate limiting ausente nas operações de quiz
- Vault ausente — validação anti-fraude de voucher não existe ainda

**Fechado neste ciclo:**
- Auditoria de SP/XP: `audit_service.dart` registra toda movimentação em `users/{uid}/audit_log`

---

## 7. Estrutura de Arquivos — Estado Real

```
e:/0- VMIND/Projetos/Spark/
├── lib/
│   ├── main.dart                         # Firebase init, FCM, OfflineSync, Crashlytics, ProviderScope
│   ├── models/
│   │   ├── user_model.dart               # + fcmToken após pull
│   │   ├── spark_admin_models.dart       # DTOs do admin: SPARKCategory, SPARKModule, SPARKTrail...
│   │   ├── progress_model.dart
│   │   ├── quiz_models.dart
│   │   ├── badge_model.dart
│   │   ├── covenant_model.dart
│   │   ├── match_models.dart
│   │   ├── curriculum_models.dart
│   │   ├── safety_error_zone.dart
│   │   └── standard_metadata.dart
│   ├── core/
│   │   ├── constants/fs.dart             # Nomes de collections/campos Firestore
│   │   └── admin/                        # Clean Architecture — admin panel
│   │       ├── domain/admin_repository.dart
│   │       ├── data/admin_repository_impl.dart
│   │       └── presentation/
│   │           ├── admin_controller.dart
│   │           ├── admin_dashboard_page.dart
│   │           └── widgets/ (9 widgets)
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── user_service.dart             # Streaks, badges, XP, FCM token
│   │   ├── progress_service.dart         # Progresso + delega para OfflineSync + GamificationService
│   │   ├── gamification_service.dart     # Missões diárias e semanais ★ novo
│   │   ├── analytics_service.dart        # Firebase Analytics — eventos de produto ★ novo
│   │   ├── audit_service.dart            # Log auditoria SP/XP em Firestore ★ novo
│   │   ├── offline_sync_service.dart     # Resiliência de conexão (Hive + auto-sync) ★ novo
│   │   ├── fcm_service.dart              # Push notifications ★ novo
│   │   ├── achievement_service.dart
│   │   ├── covenant_service.dart
│   │   ├── match_service.dart
│   │   ├── clan_service.dart
│   │   ├── question_service.dart
│   │   ├── notification_service.dart
│   │   ├── overload_service.dart
│   │   └── firebase_service.dart
│   ├── providers/
│   │   ├── user_provider.dart
│   │   ├── progress_provider.dart
│   │   └── dev_mode_provider.dart
│   ├── screens/ (30+ telas)
│   │   ├── dashboard_screen.dart         # Atualizado — mostra missões diárias
│   │   ├── leaderboard_screen.dart       # Atualizado
│   │   ├── settings_screen.dart          # Refatorado
│   │   ├── profile_screen.dart           # Atualizado
│   │   ├── store_screen.dart             # Vault placeholder
│   │   └── ... (demais telas)
│   ├── widgets/
│   ├── theme/app_theme.dart              # Tema único estático (cyberpunk dark) — Stitch pendente
│   ├── routes/app_router.dart            # 20+ rotas + rota /admin
│   ├── data/                             # Conteúdo hardcoded (legado — migrar para Firestore)
│   └── controllers/energy_controller.dart
├── exemplo.json                          # Schema de exemplo para import JSON ★ novo
├── Trilhas/                              # Material base P&C para NotebookLM ★ novo
│   └── 1. Base Teorica Proteção/
│       └── modulos 1,2,3.txt ... (6 arquivos)
├── docs/
│   ├── PRD.md
│   └── SPEC.md
├── .github/workflows/
│   ├── dart.yml
│   └── docker-image.yml
├── Dockerfile
├── firestore.rules
└── pubspec.yaml
```

---

## 8. Dependências Principais

```yaml
# Firebase
firebase_core: ^3.14.0
firebase_auth: ^5.5.4
cloud_firestore: ^5.6.7
firebase_storage: ^12.4.5
firebase_crashlytics: ^4.3.5
firebase_analytics: (adicionado)
firebase_messaging: (adicionado — FCM)

# Estado e Roteamento
flutter_riverpod: ^3.3.1
riverpod_annotation: ^3.3.1
go_router: ^17.1.0

# Resiliência de Conexão (adicionadas neste ciclo)
hive_flutter: (fila offline + cache de usuário)
connectivity_plus: (listener de status de rede)

# UI
google_fonts: ^6.1.0

# Utilitários
flutter_dotenv: ^5.2.1
intl: ^0.20.2

# Ausentes (ainda necessários):
# http / dio — API REST para The Vault (Cloud Functions)
# sqflite / workmanager — descartados (offline-first removido)
```

---

## 9. CI/CD — Estado Real

### Pipeline de CI (`dart.yml`)
```
Trigger: push ou PR para main
Steps:
  1. Setup Dart SDK
  2. dart pub get
  3. dart analyze
  4. dart test
```

### Pipeline de CD (`docker-image.yml`)
```
Trigger: push para main
Steps:
  1. Checkout
  2. Autenticar no GCP (service account via secret)
  3. Configurar Docker para gcr.io
  4. Gerar .env com secrets do GitHub (Firebase keys)
  5. Build: gcr.io/$PROJECT_ID/site:latest
  6. Push para GCP Container Registry
  7. Deploy: gcloud run deploy
     └── --memory 512Mi
     └── --min-instances 0
     └── --max-instances 1
     └── --port 80
     └── --allow-unauthenticated
```

**Observação:** `min-instances 0` significa cold starts. Para um app de aprendizado com sessões curtas, isso pode impactar negativamente a UX (primeira requisição lenta).

---

## 10. Débitos Técnicos Identificados

| Categoria | Débito | Prioridade |
|---|---|---|
| Segurança | Rota `/admin` sem guard de role — qualquer autenticado acessa | 🔴 Alta |
| Arquitetura | Dois sistemas de nível (`level` int + `tensionLevel` string) podem divergir | 🔴 Alta |
| Segurança | SP incrementáveis pelo client sem validação server-side (Vault ausente) | 🔴 Alta |
| Schema | `difficulty` no admin usa `"easy/medium/hard"`, import JSON usa `"BT/MT/AT/EAT"` — inconsistentes | 🔴 Alta |
| Arquitetura | Conteúdo hardcoded em `lib/data/` — deve migrar para Firestore via admin panel | 🟡 Média |
| Performance | Cold start no Cloud Run (min-instances=0) | 🟡 Média |
| UX | Tema estático — Design Stitch não implementado | 🟡 Média |
| Admin | Cascading delete não implementado — deletar categoria não remove módulos/lições filhos | 🟡 Média |

**Fechados neste ciclo:**
| Item | Como foi fechado |
|---|---|
| Admin panel com import JSON | `lib/core/admin/` + `AdminController.importFromJSON()` |
| Auditoria de SP/XP | `audit_service.dart` → `users/{uid}/audit_log` |
| Instrumentação de KPIs | `analytics_service.dart` → Firebase Analytics |
| Push notifications | `fcm_service.dart` → FCM token em `users/{uid}.fcmToken` |
| Resiliência de conexão | `offline_sync_service.dart` → Hive + auto-sync |

**Descartados intencionalmente:**
| Item | Decisão |
|---|---|
| ~~Offline-first (SQLite/WorkManager)~~ | Descartado — resiliência de conexão via Hive é suficiente |
| ~~Integração IA via API~~ | Descartado — NotebookLM offline + upload JSON |
