#!/usr/bin/env bash
# Commit (opcional) + push main + acompanha deploy web (Hetzner) e APK mobile.
# Uso:
#   bash scripts/deploy-all.sh -m "mensagem do commit"
#   bash scripts/deploy-all.sh --skip-commit
#   bash scripts/deploy-all.sh --web-only
#   bash scripts/deploy-all.sh --no-watch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MESSAGE=""
SKIP_COMMIT=0
WEB_ONLY=0
MOBILE_ONLY=0
NO_WATCH=0
API_VERSION_URL="${API_VERSION_URL:-https://academia.focodev.com.br/api/app/version}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message) MESSAGE="${2:-}"; shift 2 ;;
    --skip-commit) SKIP_COMMIT=1; shift ;;
    --web-only) WEB_ONLY=1; shift ;;
    --mobile-only) MOBILE_ONLY=1; shift ;;
    --no-watch) NO_WATCH=1; shift ;;
    --api-version-url) API_VERSION_URL="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *) echo "Arg desconhecido: $1"; exit 1 ;;
  esac
done

need() { command -v "$1" >/dev/null || { echo "Falta comando: $1"; exit 1; }; }
need git
need gh

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "AVISO: branch atual e '$BRANCH' (producao usa main)."
fi

mapfile -t PATHS < <( {
  git diff --cached --name-only
  git diff --name-only
  git ls-files --others --exclude-standard
} | sort -u | grep -v '^$' || true )

if [[ "$SKIP_COMMIT" -eq 0 && ${#PATHS[@]} -gt 0 ]]; then
  if [[ -z "$MESSAGE" ]]; then
    echo "Ha alteracoes. Use -m 'mensagem' ou --skip-commit."
    exit 1
  fi
  TO_ADD=()
  for p in "${PATHS[@]}"; do
    case "$p" in
      scripts/test-login.json|scripts/test-admin-login.json|.env|*.env) continue ;;
      *) TO_ADD+=("$p") ;;
    esac
  done
  if [[ ${#TO_ADD[@]} -gt 0 ]]; then
    echo "==> Commit: ${#TO_ADD[@]} arquivo(s)"
    git add -- "${TO_ADD[@]}"
    git commit -m "$MESSAGE"
  fi
elif [[ "$SKIP_COMMIT" -eq 1 ]]; then
  echo "==> Skip commit"
else
  echo "==> Working tree limpa"
fi

AHEAD="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"
if [[ "$AHEAD" -gt 0 ]]; then
  DIFF_NAMES="$(git diff --name-only origin/main..HEAD || true)"
else
  DIFF_NAMES="$(git show --name-only --pretty='' HEAD || true)"
fi
MOBILE_TOUCHED=0
if echo "$DIFF_NAMES" | grep -qE '^(mobile/|\.github/workflows/build-mobile-release\.yml)'; then
  MOBILE_TOUCHED=1
fi

echo "==> Sync origin/main"
git pull --rebase origin main
echo "==> Push origin main"
git push origin main

if [[ "$NO_WATCH" -eq 1 ]]; then
  echo "Push feito. gh run list --limit 5"
  exit 0
fi

sleep 4

wait_workflow() {
  local file="$1" label="$2"
  echo "==> Aguardando $label ($file)..."
  local id
  id="$(gh run list --workflow "$file" --branch main --limit 1 --json databaseId -q '.[0].databaseId')"
  if [[ -z "$id" || "$id" == "null" ]]; then
    echo "AVISO: nenhuma run para $file"
    return 0
  fi
  echo "    Run $id"
  gh run watch "$id" --exit-status
  echo "==> $label OK"
}

if [[ "$MOBILE_ONLY" -eq 0 ]]; then
  wait_workflow "deploy-hetzner.yml" "Deploy web (Hetzner)"
fi

if [[ "$WEB_ONLY" -eq 0 && ( "$MOBILE_ONLY" -eq 1 || "$MOBILE_TOUCHED" -eq 1 ) ]]; then
  wait_workflow "build-mobile-release.yml" "Build/publish APK"
  echo "==> Versao publicada:"
  curl -fsS "$API_VERSION_URL" || echo "(falha ao ler versao)"
  echo
elif [[ "$WEB_ONLY" -eq 0 ]]; then
  echo "==> Sem mudancas em mobile/** — APK nao rebuildado."
  echo "    Forcar: gh workflow run build-mobile-release.yml"
fi

echo
echo "Deploy concluido."
