#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/foco-academia"
BRANCH="${DEPLOY_BRANCH:-main}"
DEPLOY_KEY="/root/.ssh/github_deploy_foco_academia"

cd "$APP_DIR"

if [[ ! -d .git ]]; then
  echo "ERRO: ${APP_DIR} nao e um repositorio git."
  echo "Execute: bash ${APP_DIR}/scripts/setup-git-hetzner.sh"
  exit 1
fi

if [[ -f "$DEPLOY_KEY" ]]; then
  export GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
fi

echo "==> Atualizando codigo (origin/${BRANCH})"
git fetch origin "$BRANCH"
git reset --hard "origin/${BRANCH}"

if [[ ! -f .env ]]; then
  echo "ERRO: .env ausente em ${APP_DIR}"
  exit 1
fi

echo "==> Rebuild e restart"
docker compose up -d --build

echo "==> Status"
docker ps --filter name=foco-academia --format 'table {{.Names}}\t{{.Status}}'
echo "Deploy concluido em $(date -u +'%Y-%m-%dT%H:%M:%SZ')."
