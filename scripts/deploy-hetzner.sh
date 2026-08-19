#!/usr/bin/env bash
set -euo pipefail
# Continua o rebuild se o SSH da Actions cair (SIGHUP).
trap '' HUP

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

# Bake paralelo estoura RAM da VPS e derruba a API no meio do deploy.
export COMPOSE_BAKE=false
export COMPOSE_PARALLEL_LIMIT=1

echo "==> Sobe postgres (se ainda nao estiver)"
docker compose up -d postgres

echo "==> Build API"
docker compose build api
docker compose up -d api

echo "==> Build aluno"
docker compose build aluno
echo "==> Build instrutor"
docker compose build instrutor
echo "==> Build admin"
docker compose build admin

echo "==> Restart dos servicos"
docker compose up -d

echo "==> Reinicia nginx (atualiza IPs dos containers)"
docker compose up -d --force-recreate nginx

echo "==> Status"
docker ps --filter name=foco-academia --format 'table {{.Names}}\t{{.Status}}'
echo "Deploy concluido em $(date -u +'%Y-%m-%dT%H:%M:%SZ')."
