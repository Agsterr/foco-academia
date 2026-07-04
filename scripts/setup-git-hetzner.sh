#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/foco-academia"
REPO="${DEPLOY_REPO:-git@github.com-foco-academia:Agsterr/foco-academia.git}"
DEPLOY_KEY="/root/.ssh/github_deploy_foco_academia"
BRANCH="${DEPLOY_BRANCH:-main}"

mkdir -p /root/.ssh && chmod 700 /root/.ssh

if ! grep -q "^github.com" /root/.ssh/known_hosts 2>/dev/null; then
  ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null
fi

if [[ ! -f "$DEPLOY_KEY" ]]; then
  echo "==> Gerando deploy key (read-only)"
  ssh-keygen -t ed25519 -f "$DEPLOY_KEY" -N "" -C "hetzner-deploy-foco-academia@focodev.com.br"
fi

if ! grep -q "Host github.com-foco-academia" /root/.ssh/config 2>/dev/null; then
  cat >> /root/.ssh/config <<EOF

Host github.com-foco-academia
  HostName github.com
  User git
  IdentityFile ${DEPLOY_KEY}
  IdentitiesOnly yes
EOF
  chmod 600 /root/.ssh/config
fi

echo ""
echo "Cadastre em GitHub → Agsterr/foco-academia → Settings → Deploy keys:"
cat "${DEPLOY_KEY}.pub"
echo ""

auth_msg=$(ssh -T -o BatchMode=yes -o ConnectTimeout=10 git@github.com-foco-academia 2>&1) || true
if ! printf '%s\n' "$auth_msg" | grep -qi "successfully authenticated"; then
  echo "AVISO: adicione a deploy key e rode este script novamente."
  exit 1
fi

mkdir -p "$APP_DIR" && cd "$APP_DIR"
[[ ! -d .git ]] && git init && git remote add origin "$REPO" 2>/dev/null || git remote set-url origin "$REPO"

export GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

backup_dir="/root/setup-git-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"
[[ -f .env ]] && cp -a .env "$backup_dir/.env"

git fetch origin "$BRANCH"
git reset --hard "origin/${BRANCH}"
git clean -fd -e .env -e scripts
[[ -f "$backup_dir/.env" && ! -f .env ]] && cp -a "$backup_dir/.env" .env

chmod +x "${APP_DIR}/scripts/"*.sh 2>/dev/null || true
echo "Setup concluido. Deploy: bash ${APP_DIR}/scripts/deploy-hetzner.sh"
