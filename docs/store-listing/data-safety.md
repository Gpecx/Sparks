# Data Safety (Google Play) & Privacy Labels (App Store) — Spark

Documento pronto para preencher os formulários das lojas. Baseado no que o app
coleta hoje (Firebase Auth/Firestore/Storage/Messaging/Analytics/Crashlytics,
pagamentos via Asaas, verificação de estudante).

> ⚠️ Revisar antes de enviar: confirmar se Analytics/Crashlytics seguem ativos,
> se há coleta adicional por algum SDK novo, e os textos legais (controlador/DPO).
> A política pública está em `/privacy-policy` (rota pública no app).

---

## 1. Resumo de práticas (vale para as duas lojas)

- **Os dados são criptografados em trânsito?** Sim (HTTPS / TLS via Firebase).
- **O usuário pode pedir exclusão dos dados?** Sim — **exclusão de conta in-app**
  (Configurações → Eliminar Conta) que apaga perfil, progresso, ranking, clã e a
  conta de acesso. Também por e-mail (suporte@exs.com.br).
- **Vendemos dados?** Não.
- **Há coleta de dados de terceiros / publicidade?** Não há rede de anúncios.
- **Público infantil?** App voltado a profissionais/estudantes; não direcionado a
  crianças.

---

## 2. Google Play — Data Safety (por tipo de dado)

Para cada item: **Coletado** (vai para o servidor), **Compartilhado** (enviado a
terceiros), **Finalidade**, **Obrigatório/Opcional**.

| Tipo de dado | Coletado | Compartilhado | Finalidade | Obrig./Opc. |
|---|---|---|---|---|
| **Nome** | Sim | Não¹ | Conta, perfil, ranking | Obrigatório |
| **E-mail** | Sim | Não¹ | Conta, autenticação, suporte | Obrigatório |
| **Foto de perfil** | Sim | Não¹ | Personalização do perfil | Opcional |
| **Documentos de verificação de estudante** (fotos/arquivos) | Sim | Não¹ | Validar matrícula/benefício | Opcional |
| **Histórico de compras** | Sim | Sim → Asaas | Processar pagamento/assinatura | Opcional |
| **Info de pagamento** (cartão/Pix) | Não armazenado pelo app² | Processado por Asaas | Cobrança | Opcional |
| **Ações no app** (progresso, quizzes, XP, duelos, clãs, ranking) | Sim | Não¹ | Funcionalidade principal, gamificação | Obrigatório |
| **Logs de diagnóstico / crash** (Crashlytics, mobile) | Sim | Não¹ | Estabilidade e correção de erros | Obrigatório |
| **IDs de dispositivo / token de push (FCM)** | Sim | Não¹ | Notificações, segurança antifraude | Obrigatório |
| **Analytics de uso** (Firebase Analytics) | Sim | Não¹ | Métricas de produto | Obrigatório |

¹ "Não compartilhado" no sentido da Play: o Google Firebase atua como
**processador/infraestrutura** (não conta como "compartilhamento com terceiros").
Declarar o uso do Firebase na seção apropriada se solicitado.
² O app não guarda número de cartão; o checkout é feito pelo Asaas.

**Finalidades mais usadas (marcar):** Funcionalidade do app · Análise ·
Personalização · Gerenciamento de conta · Prevenção de fraudes/segurança.

---

## 3. App Store — Privacy Nutrition Labels (mapeamento)

Categorias da Apple e o que marcar:

- **Contact Info**: Name, Email Address → *App Functionality, Account Management*.
- **User Content**: Photos (perfil + verificação) → *App Functionality*.
- **Identifiers**: User ID, Device ID → *App Functionality, Analytics*.
- **Purchases**: Purchase History → *App Functionality* (pagamento via Asaas).
- **Usage Data**: Product Interaction → *Analytics, App Functionality*.
- **Diagnostics**: Crash Data, Performance Data → *App Functionality*.

Para cada um, a Apple pergunta se o dado é **Linked to the user** (sim, está
ligado à conta) e se é usado para **Tracking** (não — não há tracking cross-app
nem publicidade).

---

## 4. Terceiros / processadores a declarar

- **Google Firebase** — Auth, Firestore, Storage, Cloud Functions, Messaging
  (FCM), Analytics, Crashlytics, App Check. Infraestrutura/processador.
- **Asaas** — processamento de pagamentos (cartão/Pix). Recebe dados de cobrança.

---

## 5. Checklist de envio
- [ ] Confirmar Analytics/Crashlytics ativos (se desligar algum, remover do form).
- [ ] Informar URL da Política de Privacidade: rota `/privacy-policy`.
- [ ] Marcar "exclusão de conta disponível no app" (Play exige o caminho).
- [ ] Revisar razão social/CNPJ do controlador e e-mail do DPO.
