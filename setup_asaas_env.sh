#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# setup_asaas_env.sh
#
# Script para configurar as variáveis de ambiente do Asaas nas
# Cloud Functions via Firebase Secret Manager.
#
# COMO USAR:
#   1. Edite as variáveis abaixo com os valores reais.
#   2. Execute: bash setup_asaas_env.sh
#   3. Faça o deploy: firebase deploy --only functions
#
# As variáveis ficam armazenadas no Google Secret Manager e são
# injetadas automaticamente nas Cloud Functions em runtime.
# Nenhuma chave é commitada no código.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

# ── 1. Edite estes valores ────────────────────────────────────────

# Chave de API do Asaas (seu chefe enviará)
ASAAS_API_KEY='$aact_hmlg_000MzkwODA2MWY2OGM3MWRlMDU2NWM3MzJlNzZmNGZhZGY6OmY5MDQ1MDJkLTcxZDQtNGFjNi05MTg2LTM4YTE4YjFiYTliYjo6JGFhY2hfNjNiN2EwNGQtZTI0Mi00MmM4LWI3NzgtMGNmZjE1NzQwOTY4'

# URL base:
#   Sandbox   → https://sandbox.asaas.com/api/v3
#   Produção  → https://api.asaas.com/v3
ASAAS_BASE_URL="https://sandbox.asaas.com/api/v3"

# Token para validar eventos de webhook (você define, e configura no painel Asaas)
ASAAS_WEBHOOK_TOKEN="spark_webhook_secret_key_2026"

# ── 2. Não altere abaixo ──────────────────────────────────────────

echo "🔐 Configurando segredos do Asaas nas Cloud Functions..."

echo -n "$ASAAS_API_KEY"      | firebase functions:secrets:set ASAAS_API_KEY
echo -n "$ASAAS_BASE_URL"     | firebase functions:secrets:set ASAAS_BASE_URL
echo -n "$ASAAS_WEBHOOK_TOKEN"| firebase functions:secrets:set ASAAS_WEBHOOK_TOKEN

echo ""
echo "✅ Segredos configurados com sucesso!"
echo ""
echo "Próximos passos:"
echo "  1. Faça o deploy:  firebase deploy --only functions"
echo "  2. No painel Asaas → Configurações → Webhook, configure a URL:"
echo "     https://southamerica-east1-spark-v1-e0eb5.cloudfunctions.net/asaasWebhook"
echo "  3. No campo 'Token de autenticação' do webhook, use o ASAAS_WEBHOOK_TOKEN acima."
