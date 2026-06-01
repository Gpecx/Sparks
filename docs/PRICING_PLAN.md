# SPARK — Plano de Precificação e Implementação

> **Status:** Aprovado pelo product owner (Fábio) em Jun/2026
> **Para:** Equipe de desenvolvimento
> **Objetivo:** Implementar sistema de planos (Free / Pro / Premium / Student / Business) com trial gratuito e gateway de pagamento.

---

## 1. Visão Geral dos Planos

5 planos: **Free**, **Pro**, **Premium**, **Student**, **Business**.

| Plano | Mensal | Anual | Público-alvo |
|---|---|---|---|
| 🆓 **SPARK Free** | R$ 0 | R$ 0 | Curioso / experimentador |
| ⚡ **SPARK Pro** | R$ 39,90 | R$ 399 *(economia 17%)* | Profissional individual |
| 🏆 **SPARK Premium** | R$ 79,90 | R$ 799 *(economia 17%)* | Sênior / consultor |
| 🎓 **SPARK Student** | R$ 19,90 | R$ 199 *(economia 17%)* | Estudante (com comprovação) |
| 🏢 **SPARK Business** | A partir de R$ 29/usuário/mês *(min 5 usuários)* | Faturado anual | Empresas e consultorias |

### Trial gratuito (todos os planos pagos)

- **7 dias gratuitos** do plano **Pro** para qualquer usuário Free
- Não precisa cartão para iniciar trial? **Decisão futura** — recomendo SIM precisar cartão pra reduzir churn pós-trial
- Após o trial: usuário automaticamente migra pro Pro mensal (a menos que cancele)

---

## 2. Matriz de Funcionalidades por Plano

| Funcionalidade | Free | Pro | Premium | Student | Business |
|---|:---:|:---:|:---:|:---:|:---:|
| **Categorias visíveis** | Todas (10) | Todas | Todas | Todas | Todas |
| **Módulos visíveis** | Todos (62) | Todos | Todos | Todos | Todos |
| **Trilhas acessíveis** | 1ª de cada módulo *(62 trilhas)* | Todas (311) | Todas | Todas | Todas |
| **E-books** | **Só 1º capítulo** de cada | Completos | Completos | Completos | Completos |
| **Ferramentas (calculadoras)** | 3 básicas *(Comp. Simétricas, PU, RTC/RTP)* | Todas (8+) | Todas | Todas | Todas |
| **Certificados de conclusão** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Modo offline** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Sem anúncios** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Estatísticas avançadas** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Personalização (tema dinâmico)** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Tutoria 1:1 mensal (1h)** | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Acesso antecipado a novo conteúdo** | ❌ | ❌ | ✅ | ❌ | ✅ |
| **Selo "Membro Fundador"** *(apenas primeiros 100)* | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Suporte prioritário (SLA 12h)** | ❌ | ❌ | ✅ | ❌ | ✅ |
| **Painel admin de equipe** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Relatórios de progresso da equipe** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Faturamento empresarial (NF-e)** | ❌ | ❌ | ❌ | ❌ | ✅ |

### Ferramentas no Free (3 calculadoras)

Selecionar as 3 mais fundamentais:
1. **Componentes Simétricas**
2. **Valor por Unidade (PU)**
3. **RTC/RTP**

As demais (Curto-Circuito, Curvas 51 IDMT, Diferencial 87T, Queda de Tensão, FP, SPDA, etc.) ficam exclusivas dos planos pagos.

---

## 3. Modelo de Dados (Firestore)

### Atualizar coleção `users/{uid}`

Adicionar campos:

```typescript
{
  // ... campos existentes (uid, email, role, xp, sparkPoints, etc.)

  // Plano
  plan: "free" | "pro" | "premium" | "student" | "business",
  planStartedAt: Timestamp,
  planExpiresAt: Timestamp | null,         // null = perpétuo (free)
  planBillingPeriod: "monthly" | "yearly" | null,
  planAutoRenew: boolean,

  // Trial
  trialUsed: boolean,                       // já usou o trial?
  trialStartedAt: Timestamp | null,
  trialEndsAt: Timestamp | null,

  // Status financeiro
  stripeCustomerId: string | null,          // ou pagseguroCustomerId / mpCustomerId
  subscriptionId: string | null,
  paymentMethod: "card" | "pix" | "boleto" | null,
  lastPaymentAt: Timestamp | null,
  nextPaymentAt: Timestamp | null,
  paymentStatus: "active" | "past_due" | "canceled" | "trialing" | null,

  // Validação Student
  studentVerified: boolean,
  studentVerifiedAt: Timestamp | null,
  studentInstitution: string | null,
  studentEnrollmentExpiresAt: Timestamp | null,  // revalidação anual

  // Business
  businessOrgId: string | null,             // referência à organização
  businessRole: "owner" | "member" | null,
}
```

### Nova coleção `organizations/{orgId}` (Business)

```typescript
{
  name: string,
  cnpj: string,
  ownerUid: string,
  memberUids: string[],
  seats: number,
  plan: "business",
  billingPeriod: "monthly" | "yearly",
  subscriptionId: string,
  createdAt: Timestamp,
  expiresAt: Timestamp,
}
```

### Nova coleção `plans_catalog/{planId}` (configurável sem deploy)

```typescript
{
  planId: "free" | "pro" | "premium" | "student" | "business",
  name: string,                             // "SPARK Pro"
  monthlyPrice: number,                     // 39.90
  yearlyPrice: number,                      // 399.00
  features: {
    trailsPerModule: number | "all",        // 1 ou "all"
    ebookChapters: number | "all",          // 1 ou "all"
    toolsAccess: string[] | "all",          // ["sym_components", "pu", "rtc_rtp"]
    certificates: boolean,
    offlineMode: boolean,
    noAds: boolean,
    advancedStats: boolean,
    customization: boolean,
    monthlyTutoring: boolean,
    earlyAccess: boolean,
    prioritySupport: boolean,
    teamPanel: boolean,
    teamReports: boolean,
    invoicing: boolean,
  },
  active: boolean,
  order: number,
}
```

> **Vantagem:** preços e features ficam editáveis sem deploy de código.

---

## 4. Lógica de Gating (Bloqueio de Acesso)

Centralizar em um service: `lib/services/access_control_service.dart`

### Métodos principais

```dart
class AccessControlService {
  // Plano atual do usuário
  UserPlan get currentPlan;

  // Helpers booleanos
  bool canAccessTrail(SPARKTrail trail);      // verifica se é 1ª do módulo OU plano pago
  bool canAccessEbookChapter(int chapterIndex); // só 1º cap para free
  bool canAccessTool(String toolId);           // verifica lista de ferramentas do plano
  bool canDownloadCertificate();
  bool canUseOfflineMode();
  bool shouldShowAds();

  // Trial
  bool isOnTrial;
  int trialDaysRemaining;
  Future<void> startTrial();

  // Helpers de UI
  String upgradeMessageFor(String feature);   // mensagem contextual de upgrade
  void showUpgradeBottomSheet(BuildContext context, {String? trigger});
}
```

### Onde aplicar o gating

| Ponto da UI | Regra | O que fazer no Free |
|---|---|---|
| Lista de trilhas do módulo | `canAccessTrail()` | Mostrar todas, mas com 🔒 nas que não são a 1ª. Tap abre upgrade |
| Leitor de e-book | `canAccessEbookChapter(idx)` | Após o cap 1, mostrar "Desbloqueie capítulos 2-N" |
| Lista de ferramentas | `canAccessTool(id)` | Mostrar grid com 🔒 nas bloqueadas |
| Tela de certificado | `canDownloadCertificate()` | Botão "Baixar certificado" → upgrade modal |
| Configurações de tema | `canUseCustomization()` | Opções extras com cadeado |

---

## 5. UI/UX — Novas Telas e Componentes

### Telas novas

1. **`lib/screens/pricing_screen.dart`** — Tela de planos
   - Cards lado a lado (Free, Pro, Premium, Student)
   - Toggle Mensal/Anual
   - Destaque visual do Pro (mais popular)
   - CTA: "Iniciar trial de 7 dias"
   - Tab "Empresarial" no topo levando a formulário B2B

2. **`lib/screens/upgrade_modal.dart`** — Modal contextual de upgrade
   - Disparado quando usuário tenta acessar feature bloqueada
   - Mensagem contextual (ex: "Desbloqueie todas as trilhas deste módulo")
   - Mostra Pro como recomendado
   - CTA primário: trial de 7 dias

3. **`lib/screens/subscription_screen.dart`** — Gerenciamento da assinatura
   - Plano atual + data de renovação
   - Mudar plano / cancelar
   - Histórico de pagamentos
   - Método de pagamento

4. **`lib/screens/student_verification_screen.dart`**
   - Upload de comprovante de matrícula (foto/PDF)
   - Email institucional como alternativa (`.edu.br`)
   - Status: pendente, aprovado, rejeitado
   - Revalidação anual

5. **`lib/screens/business/business_setup_screen.dart`** — Formulário B2B
   - Dados da empresa (CNPJ, razão social, contato)
   - Número de licenças
   - Período de faturamento
   - Gera proposta automática + link de pagamento ou contato comercial

6. **`lib/screens/business/team_dashboard_screen.dart`** — Painel da empresa
   - Lista de membros
   - Progresso médio / por usuário
   - Adicionar/remover membros
   - Trocar dono da conta

### Componentes reutilizáveis

- **`PlanBadge`** — selo no perfil ("Free", "Pro", "Premium", "Student", "Business")
- **`LockedFeatureBanner`** — banner pequeno com cadeado + "Upgrade para Pro"
- **`TrialCountdown`** — contador no topo da home durante trial ("3 dias restantes do seu trial Pro")
- **`UpgradePromptBottomSheet`** — bottom sheet padronizado para upgrade

---

## 6. Gateway de Pagamento

### Recomendação: **Stripe** + **Mercado Pago** (combo)

**Por quê combo?**
- **Stripe:** melhor SDK Flutter, internacional, ótimo para cartão (Pro/Premium/Student)
- **Mercado Pago:** PIX nativo + boleto + parcelamento sem juros (público BR mais sensível a preço)

### Implementação sugerida

```dart
// lib/services/payment/
abstract class PaymentService {
  Future<Subscription> createSubscription(PlanType plan, BillingPeriod period);
  Future<void> cancelSubscription(String subscriptionId);
  Future<void> updatePaymentMethod(String customerId);
  Stream<PaymentEvent> paymentEvents();
}

class StripePaymentService implements PaymentService { ... }
class MercadoPagoPaymentService implements PaymentService { ... }
```

### Fluxo de assinatura (Stripe)

1. Usuário escolhe plano + período → frontend cria PaymentIntent via Cloud Function
2. Coleta cartão via `flutter_stripe`
3. Confirma o pagamento → Stripe cria a Subscription
4. Webhook Stripe → Cloud Function → atualiza `users/{uid}.plan*` no Firestore
5. UI escuta o doc do usuário e atualiza automaticamente

### Cloud Functions necessárias

- `createCheckoutSession` — gera link/PaymentIntent
- `handleStripeWebhook` — sync de eventos (created, updated, deleted, payment_failed)
- `handleMercadoPagoWebhook` — idem para MP
- `cancelSubscription` — cancela e atualiza Firestore
- `processStudentVerification` — admin aprova/rejeita upload
- `createBusinessSubscription` — fluxo B2B com NF-e

### Outros gateways alternativos (caso queira testar)

- **PagSeguro PagBank** — bom para PJ
- **Asaas** — barato para SaaS BR
- **Iugu** — focado em assinatura SaaS

---

## 7. Trial Gratuito (Lógica)

### Regras

- Disponível **uma única vez** por usuário (`trialUsed: true` após uso)
- **7 dias** de Pro completo
- Usuário **precisa cadastrar cartão** ao iniciar (reduz churn)
- 24h antes do fim: notificação push + email com aviso
- No fim do trial: cobrança automática do 1º mês Pro
- Cancelamento durante o trial: não cobra, volta para Free imediatamente

### Implementação

```dart
Future<void> startTrial() async {
  if (user.trialUsed) throw 'Trial já utilizado';

  // 1. Coleta cartão via Stripe (não cobra ainda)
  final paymentMethodId = await StripeService.collectPaymentMethod();

  // 2. Cria Subscription no Stripe com trial_period_days: 7
  final sub = await CloudFunctions.startTrial(paymentMethodId, plan: 'pro');

  // 3. Atualiza Firestore
  await usersRef.update({
    'plan': 'pro',
    'trialUsed': true,
    'trialStartedAt': FieldValue.serverTimestamp(),
    'trialEndsAt': sub.trialEnd,
    'subscriptionId': sub.id,
    'paymentStatus': 'trialing',
  });
}
```

---

## 8. Plano Student — Validação

### Fluxo

1. Usuário escolhe Student na tela de planos
2. Sobe foto/PDF do comprovante OU email institucional (`*.edu.br`)
3. Status fica `pending` — admin aprova manualmente nos primeiros meses
4. Após aprovação: ativa o plano com preço Student (R$ 19,90 ou R$ 199)
5. Re-verificação obrigatória a cada **12 meses**

### Aprovação rápida (MVP)

Use email com domínio `.edu.br` (lista no backend) para auto-aprovação. Outros casos passam pelo admin.

---

## 9. Plano Business — Fluxo

### Auto-serviço (5–10 usuários)

1. Empresa preenche formulário (`business_setup_screen.dart`)
2. Sistema gera link de pagamento via Stripe Invoicing ou MP empresa
3. Após pagamento: cria `organizations/{orgId}` e convida emails
4. Dono recebe acesso ao `team_dashboard_screen.dart`

### Atendimento comercial (10+ usuários)

1. Empresa preenche formulário
2. Sistema envia email pra comercial@spark.com.br
3. Comercial faz orçamento customizado
4. Após fechamento: equipe cria org manualmente

---

## 10. Cancelamento e Churn

### Regras

- Cancelamento **a qualquer momento** (LGPD/CDC)
- Mantém acesso até o fim do período pago
- Não há reembolso parcial (deixe claro no checkout)
- Após expiração: rebaixa para Free, mantém histórico/progresso

### UX

- Botão "Cancelar assinatura" em `subscription_screen.dart`
- Antes de confirmar: tela de retenção com:
  - Motivo da saída (radio)
  - Oferta: "30% off nos próximos 3 meses"
  - Pause: "Pause sua assinatura por até 3 meses"
- Após confirmação: email + push de despedida e oferta de retorno

---

## 11. Analytics e Métricas

### Eventos a trackear (Firebase Analytics + Mixpanel/Amplitude opcional)

```dart
// Conversão
analytics.logEvent('pricing_viewed');
analytics.logEvent('plan_selected', params: {'plan': 'pro', 'period': 'monthly'});
analytics.logEvent('trial_started');
analytics.logEvent('subscription_created', params: {'plan', 'price', 'period'});
analytics.logEvent('subscription_canceled', params: {'reason'});

// Engagement
analytics.logEvent('upgrade_prompt_shown', params: {'trigger': 'trail_locked'});
analytics.logEvent('upgrade_prompt_clicked', params: {'trigger'});
analytics.logEvent('upgrade_prompt_dismissed');

// Gating
analytics.logEvent('locked_feature_accessed', params: {'feature': 'tool', 'tool_id': 'arc_flash'});
```

### Métricas-chave (KPIs)

- **MRR** (Monthly Recurring Revenue)
- **ARR** (Annual)
- **Churn mensal** — meta < 8%
- **Trial → Pro conversion** — meta > 30%
- **Free → Trial conversion** — meta > 5%
- **CAC** (Custo de Aquisição)
- **LTV** (Lifetime Value)
- **LTV/CAC** — meta > 3x

---

## 12. Segurança e Anti-Fraude

- **Não confiar no client** para decisões de plano — toda lógica crítica nas Cloud Functions
- **Firestore Security Rules**: leitura de `plan` é OK; escrita só via Functions (Admin SDK)
- **Validar webhooks** com signature secret (Stripe / MP)
- **Idempotência** em todos os webhooks (use `eventId` para dedup)
- **Rate limit** no endpoint de trial (1 trial por CPF/email)
- **Detecção de fraude**: bloquear se múltiplas contas Free do mesmo IP/dispositivo tentam virar trial

---

## 13. Atualizações nas Firestore Security Rules

Adicionar verificações de plano em pontos críticos:

```javascript
// Exemplo: lições só desbloqueiam para usuários com plano que dá acesso
match /categories/{catId}/modules/{modId}/trails/{trailId}/lessons/{lessonId} {
  allow read: if isAuthenticated() && (
    isAdmin() ||
    isFirstTrailOfModule(catId, modId, trailId) ||  // Free pode ler 1ª trilha
    userHasPaidPlan()                                // Pro/Premium/Student/Business
  );
}

function userHasPaidPlan() {
  let plan = get(/databases/$(database)/documents/users/$(request.auth.uid)).data.plan;
  return plan in ['pro', 'premium', 'student', 'business'];
}
```

> **Nota:** isFirstTrailOfModule é complexo de fazer só com rules — pode ser mais prático bloquear no client e validar no servidor (Cloud Function ao buscar questões).

---

## 14. Roadmap de Implementação (sugestão)

### Sprint 1 (1–2 semanas) — Base
- [ ] Modelo de dados (Firestore + Firebase Auth fields)
- [ ] `AccessControlService` com lógica de gating
- [ ] Atualizar Firestore Rules
- [ ] `plans_catalog` no Firestore

### Sprint 2 (1 semana) — UI
- [ ] `PricingScreen`
- [ ] `UpgradeModal`
- [ ] `PlanBadge`, `LockedFeatureBanner`, `TrialCountdown`
- [ ] Gating na lista de trilhas, leitor de e-books, lista de ferramentas

### Sprint 3 (2 semanas) — Pagamento
- [ ] Cloud Functions de assinatura (Stripe + MP)
- [ ] `flutter_stripe` integrado
- [ ] Webhooks
- [ ] `SubscriptionScreen` (gerenciamento)
- [ ] Trial flow completo

### Sprint 4 (1 semana) — Student + Business
- [ ] `StudentVerificationScreen` + flow
- [ ] `BusinessSetupScreen` + Cloud Function
- [ ] `TeamDashboardScreen`

### Sprint 5 (1 semana) — Polimento
- [ ] Analytics completo
- [ ] Tela de retenção / cancelamento
- [ ] Notificações de fim de trial
- [ ] QA e testes de edge cases

**Total estimado: 6–7 semanas** com 1 dev sênior.

---

## 15. Anexos

### A. Texto de marketing de cada plano

**Free**
> Comece sua jornada no SPCS. Acesso à primeira trilha de cada módulo, 3 ferramentas essenciais e o primeiro capítulo dos e-books. Perfeito para conhecer a plataforma.

**Pro** *(mais popular)*
> Acesso ilimitado a 311 trilhas, todos os e-books, todas as ferramentas, certificados e modo offline. Para o profissional que quer dominar SPCS.

**Premium**
> Tudo do Pro + 1h de tutoria mensal 1:1, acesso antecipado a novo conteúdo e suporte prioritário. Para o consultor e o sênior que precisa de profundidade.

**Student**
> Mesmas funcionalidades do Pro com 50% de desconto. Para estudantes de engenharia elétrica com matrícula ativa.

**Business**
> Treine sua equipe. Painel admin, relatórios de progresso, faturamento via NF-e e desconto por volume.

### B. Lista de domínios `.edu.br` para auto-aprovação Student

Manter em `lib/data/student_domains.dart` ou Firestore `config/student_domains`:
- ufmg.edu.br, usp.br, unicamp.br, ufrj.br, ufpe.br, ufsc.br, ufrgs.br, etc.
- Lista completa via parsing do INEP/MEC

### C. Modelo de email de fim de trial (Sprint 5)

```
Assunto: Seu trial do SPARK Pro termina amanhã ⚡

Olá [nome],

Seu trial gratuito de 7 dias termina amanhã às [hora]. A partir de então,
você será cobrado R$ 39,90/mês (ou seu plano selecionado) automaticamente.

✅ Você concluiu X trilhas durante o trial
✅ Acessou Y e-books
✅ Usou Z ferramentas

Quer continuar? Não precisa fazer nada — a renovação acontece automaticamente.
Quer cancelar? [Botão: Gerenciar minha assinatura]

Equipe SPARK
```

---

## 16. Decisões pendentes (próximas iterações)

- [ ] Definir cores/visual de cada plano (selo dourado para Premium?)
- [ ] Selo "Membro Fundador" — apenas primeiros 100? Definir critério exato
- [ ] Acesso antecipado a novo conteúdo (Premium) — quantos dias antes?
- [ ] Tutoria 1:1 — implementar agendamento via Calendly ou integrado?
- [ ] Política de reembolso — definir formalmente
- [ ] Programa de afiliados / cupom de indicação — definir percentuais

---

**Documento aprovado pelo Product Owner.**
**Próximo passo:** dev faz refinamento técnico e abre tickets/issues por sprint.
