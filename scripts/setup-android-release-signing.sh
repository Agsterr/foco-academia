#!/usr/bin/env bash
# Gera keystore de release Android e cadastra secrets no GitHub Actions.
# Uso: bash scripts/setup-android-release-signing.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="${ROOT}/mobile/android"
KEYSTORE="${ANDROID_DIR}/app/upload-keystore.jks"
ALIAS="${ANDROID_KEY_ALIAS:-foco-academia-upload}"
VALIDITY_YEARS="${ANDROID_KEY_VALIDITY_YEARS:-25}"
REPO="${GITHUB_REPO:-Agsterr/foco-academia}"

if ! command -v keytool >/dev/null 2>&1; then
  echo "ERRO: keytool (JDK) não encontrado."
  exit 1
fi

STORE_PASS=""
KEY_PASS=""

if [[ -f "$KEYSTORE" ]]; then
  echo "Keystore já existe: ${KEYSTORE}"
  if [[ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]]; then
    echo "Defina ANDROID_KEYSTORE_PASSWORD para recadastrar os secrets no GitHub."
    exit 1
  fi
  STORE_PASS="${ANDROID_KEYSTORE_PASSWORD}"
  KEY_PASS="${ANDROID_KEY_PASSWORD:-$STORE_PASS}"
else
  STORE_PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)"
  KEY_PASS="$STORE_PASS"

  keytool -genkeypair \
    -v \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity $((VALIDITY_YEARS * 365)) \
    -storepass "$STORE_PASS" \
    -keypass "$KEY_PASS" \
    -dname "CN=Foco Academia, OU=Mobile, O=FocoDev, L=Brasil, ST=BR, C=BR"

  echo "Keystore criado: ${KEYSTORE}"
fi

BASE64_KEYSTORE="$(base64 -w0 "$KEYSTORE" 2>/dev/null || base64 < "$KEYSTORE" | tr -d '\n')"

if command -v gh >/dev/null 2>&1; then
  echo "==> Cadastrando secrets no GitHub (${REPO})"
  printf '%s' "$BASE64_KEYSTORE" | gh secret set ANDROID_KEYSTORE_BASE64 --repo "$REPO"
  printf '%s' "$STORE_PASS" | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
  printf '%s' "$ALIAS" | gh secret set ANDROID_KEY_ALIAS --repo "$REPO"
  printf '%s' "$KEY_PASS" | gh secret set ANDROID_KEY_PASSWORD --repo "$REPO"
  echo "Secrets ANDROID_KEYSTORE_* configurados."
else
  echo "Configure manualmente em Settings → Secrets → Actions:"
  echo "ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD"
fi

cat <<'EOF'

=== Após configurar os secrets ===
1. Defina APP_RELEASE_DEPLOY_TOKEN no servidor e no GitHub (setup-github-mobile-release-secret.sh)
2. Push em mobile/ dispara build e publicação automática no painel admin
3. Use a MESMA chave release sempre — atualizações OTA não exigem desinstalar
4. Se houver conflito de assinatura: desinstale uma vez e reinstale o APK assinado

EOF
