#!/usr/bin/env bash
# Cadastra APP_RELEASE_DEPLOY_TOKEN no GitHub Actions (valor do servidor Hetzner).
set -euo pipefail

SSH_HOST="${SSH_HOST:-hetzner}"
REPO="${GITHUB_REPO:-Agsterr/foco-academia}"

if ! command -v gh >/dev/null 2>&1; then
  echo "Instale o GitHub CLI: https://cli.github.com/"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Execute: gh auth login"
  exit 1
fi

TOKEN="$(ssh "${SSH_HOST}" "grep '^APP_RELEASE_DEPLOY_TOKEN=' /opt/foco-academia/.env | cut -d= -f2-")"
if [ -z "${TOKEN}" ]; then
  echo "APP_RELEASE_DEPLOY_TOKEN não encontrado em /opt/foco-academia/.env"
  echo "Gere um token: openssl rand -hex 32"
  echo "Adicione no .env do servidor e rode este script novamente."
  exit 1
fi

printf '%s' "${TOKEN}" | gh secret set APP_RELEASE_DEPLOY_TOKEN --repo "${REPO}"
echo "Secret APP_RELEASE_DEPLOY_TOKEN configurado em ${REPO}."
