# 🚀 SPARK — Checklist de Lançamento

## ✅ Bugs Corrigidos Nesta Versão
- [x] `registerWithEmail` agora inclui `eloRating`, `wins`, `losses`, `totalDuels` (eram omitidos, causando erros no sistema de duelos para usuários novos)
- [x] `print()` → `debugPrint()` no `auth_service.dart` (não vaza logs em produção)
- [x] `app_router.dart` — Adicionado guard de autenticação: rotas protegidas redirecionam para `/login` se não logado; usuário logado é redirecionado de `/login` e `/` para `/home`
- [x] `web/manifest.json` — Nome e cores corrigidos (era "spark_app" / azul Flutter padrão)
- [x] `ios/Runner/Info.plist` — `CFBundleName` corrigido para "SPARK"
- [x] `android/build.gradle.kts` — Template de release signing adicionado
- [x] `.env.example` criado para documentar variáveis necessárias

---

## 🔴 BLOQUEADORES de Lançamento (Fazer Antes de Publicar)

### 1. Pagamento Real
- O `CheckoutScreen` e `StoreScreen` têm UI de compra mas **nenhum gateway de pagamento real**.
- Atualmente apenas grava no Firestore sem cobrar nada.
- **Ação:** Integrar `in_app_purchase` (Play Store / App Store) OU Stripe/Mercado Pago para a web.

### 2. Sistema de Duelos (Mock)
- `MatchService` usa mock com delay artificial de 2-4 segundos para simular matchmaking.
- Não há matchmaking real entre usuários.
- **Ação:** Implementar Firebase Realtime Database ou Cloud Functions para matchmaking real, ou marcar o recurso como "Em breve" na UI.

### 3. Notificações (NotificationService é Mock)
- `NotificationService` gera notificações fake locais. O `FcmService` existe mas as notificações in-app são mockadas.
- **Ação:** Conectar `NotificationService` ao Firestore real ou usar `flutter_local_notifications` com dados do Firestore.

### 4. Release Signing (Android)
- O `build.gradle.kts` ainda usa `signingConfigs.getByName("debug")` para release.
- **Ação:** Criar keystore de produção e configurar `signingConfigs.release`:
  ```bash
  keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias spark
  ```

### 5. Application ID
- `applicationId = "com.spark.spark_app"` — verifique disponibilidade na Play Store.
- **Ação:** Mudar para algo como `com.seunome.spark` antes de submeter.

### 6. Ícones Customizados
- Os ícones ainda são os padrões do Flutter (ícone azul genérico).
- **Ação:** Usar `flutter_launcher_icons` com o logo SPARK real.

### 7. Splash Screen
- Sem splash screen nativa configurada.
- **Ação:** Usar `flutter_native_splash` para tela de splash customizada.

---

## 🟡 Melhorias Importantes (Antes do Lançamento Público)

### Conteúdo
- Apenas 3 módulos de dados hardcoded (`bloco01_mod01_data.dart`, etc.)
- O admin panel permite criar conteúdo no Firestore, mas o app lê dados hardcoded no `lessons_registry.dart`
- **Ação:** Garantir que todo conteúdo seja servido pelo Firestore via admin panel

### Termos de Uso e Política de Privacidade
- Não há telas de ToS/Privacidade (obrigatórias na Play Store e App Store)
- **Ação:** Criar telas e vincular no onboarding e configurações

### Acessibilidade
- Algumas telas têm `Semantics` label mas não é consistente
- **Ação:** Auditoria completa de acessibilidade antes da publicação

---

## 🟢 O Que Está Bem Implementado
- Firebase Auth + Firestore com regras de segurança robustas
- Crashlytics configurado para erros de produção
- Analytics integrado nos eventos principais
- Offline sync via Hive
- Sistema de gamificação (XP, SP, streaks, badges, duelos) bem estruturado
- Cloud Functions para operações sensíveis (XP, ELO, badges)
- Audit log por usuário
- Admin dashboard completo
- Onboarding com minigame
- 4 tipos de questão (múltipla escolha, swipe V/F, drag & drop, sentence builder)
