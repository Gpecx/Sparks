#!/usr/bin/env bash
# Gera o build de release do SPARK para Android.
#
# Uso: na raiz do projeto (Linux/macOS):
#   ./scripts/build_release.sh           -> gera APK de release (instalar direto no aparelho)
#   ./scripts/build_release.sh appbundle -> gera AAB de release (publicar na Play Store)
#
# A flag --no-tree-shake-icons e OBRIGATORIA: o app usa icones dinamicos de cla
# (IconData montado a partir do iconCodePoint salvo no Firestore), e o tree-shaking
# de icones quebra o build nesse caso. Por isso ja vai embutida aqui.

set -euo pipefail

# Vai para a raiz do projeto (pasta acima de scripts/).
cd "$(dirname "$0")/.."

TARGET="${1:-apk}"

echo "==> Garantindo dependencias (flutter pub get)..."
flutter pub get

case "$TARGET" in
  apk)
    echo "==> Gerando APK de release..."
    flutter build apk --release --no-tree-shake-icons
    echo "==> Pronto: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  appbundle|aab)
    echo "==> Gerando App Bundle (AAB) de release..."
    flutter build appbundle --release --no-tree-shake-icons
    echo "==> Pronto: build/app/outputs/bundle/release/app-release.aab"
    ;;
  *)
    echo "Alvo invalido: '$TARGET'. Use 'apk' (padrao) ou 'appbundle'." >&2
    exit 1
    ;;
esac
