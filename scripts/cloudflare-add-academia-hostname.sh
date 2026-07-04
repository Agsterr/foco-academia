#!/usr/bin/env bash
# Adiciona academia.focodev.com.br ao tunel gerenciamento-estoque (preserva ingress existente).
set -euo pipefail

HOSTNAME="${PUBLIC_HOSTNAME:-academia.focodev.com.br}"
ORIGIN="${ACADEMIA_ORIGIN:-http://127.0.0.1:8088}"
ZONE_NAME="${CLOUDFLARE_ZONE_NAME:-focodev.com.br}"
ESTOQUE_ENV="${ESTOQUE_ENV:-/opt/gerenciamento-estoque/.env}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

if [[ -z "$API_TOKEN" ]]; then
  if [[ -f /opt/app-rotas/.env ]]; then
    API_TOKEN="$(grep '^CLOUDFLARE_API_TOKEN=' /opt/app-rotas/.env | cut -d= -f2- | tr -d '\r\n' || true)"
  fi
fi

if [[ -z "$API_TOKEN" ]] || [[ ${#API_TOKEN} -lt 20 ]]; then
  if [[ -f /root/.secrets/cloudflare-certbot.ini ]]; then
    API_TOKEN="$(grep 'dns_cloudflare_api_token' /root/.secrets/cloudflare-certbot.ini | sed 's/.*= *//' | tr -d '\r\n\"' || true)"
  fi
fi

if [[ -z "$API_TOKEN" ]] || [[ ${#API_TOKEN} -lt 20 ]]; then
  cat <<EOF
================================================================================
Cloudflare — configure manualmente (CLOUDFLARE_API_TOKEN invalido ou ausente)
================================================================================
Tunel: gerenciamento-estoque
Adicionar Public Hostname -> ${ORIGIN}:
  - ${HOSTNAME}

DNS CNAME (proxied) na zona focodev.com.br:
  academia -> <tunnel-id>.cfargotunnel.com
================================================================================
EOF
  exit 1
fi

readarray -t IDS < <(ESTOQUE_ENV="$ESTOQUE_ENV" python3 - <<'PY'
import json, base64, os
env = os.environ["ESTOQUE_ENV"]
token = None
for line in open(env):
    if line.startswith("CLOUDFLARED_TUNNEL_TOKEN="):
        token = line.split("=", 1)[1].strip()
        break
if not token:
    raise SystemExit("CLOUDFLARED_TUNNEL_TOKEN ausente no estoque")
raw = token + "=" * (-len(token) % 4)
data = json.loads(base64.urlsafe_b64decode(raw))
print(data["a"])
print(data["t"])
PY
)
ACCOUNT_ID="${IDS[0]}"
TUNNEL_ID="${IDS[1]}"
TUNNEL_CNAME="${TUNNEL_ID}.cfargotunnel.com"

PAYLOAD=$(HOSTNAME="$HOSTNAME" ORIGIN="$ORIGIN" \
  ACCOUNT_ID="$ACCOUNT_ID" TUNNEL_ID="$TUNNEL_ID" API_TOKEN="$API_TOKEN" python3 - <<'PY'
import json, os, urllib.request

account_id = os.environ["ACCOUNT_ID"]
tunnel_id = os.environ["TUNNEL_ID"]
token = os.environ["API_TOKEN"]
origin = os.environ["ORIGIN"]
new_host = os.environ["HOSTNAME"]

url = f"https://api.cloudflare.com/client/v4/accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations"
req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
with urllib.request.urlopen(req) as resp:
    current = json.load(resp)

ingress = current["result"]["config"]["ingress"]
catch_all = ingress.pop() if ingress and ingress[-1].get("service", "").startswith("http_status") else {"service": "http_status:404"}

existing = {item.get("hostname"): item for item in ingress if "hostname" in item}
existing[new_host] = {"hostname": new_host, "service": origin}

ordered = []
seen = set()
for item in ingress:
    h = item.get("hostname")
    if h and h in existing:
        ordered.append(existing[h])
        seen.add(h)
    elif h and h != new_host:
        ordered.append(item)
        seen.add(h)

if new_host not in seen:
    ordered.append(existing[new_host])

ordered.append(catch_all)
print(json.dumps({"config": {"ingress": ordered}}))
PY
)

HTTP=$(curl -sS -o /tmp/cf_academia_tunnel.json -w '%{http_code}' \
  -X PUT "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations" \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD")

if [[ "$HTTP" != "200" ]]; then
  echo "ERRO: API Cloudflare HTTP $HTTP"
  cat /tmp/cf_academia_tunnel.json
  exit 1
fi

echo "OK: ingress atualizado (${HOSTNAME} -> ${ORIGIN})."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "${SCRIPT_DIR}/cloudflare-dns-academia.sh" || true

echo "Aguarde ~30s e teste:"
echo "  curl -s https://${HOSTNAME}/api/health"
echo "  curl -sI https://${HOSTNAME}/"
echo "  curl -sI https://${HOSTNAME}/instrutor/"
