#!/usr/bin/env bash
# Cria CNAME academia -> tunel (requer CLOUDFLARE_ZONE_ID ou token com Zone Read).
set -euo pipefail

ZONE_NAME="${CLOUDFLARE_ZONE_NAME:-focodev.com.br}"
ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
TUNNEL_CNAME="${TUNNEL_CNAME:-4fe3f6e0-d2ec-4bca-8459-e66f81d95494.cfargotunnel.com}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

if [[ -z "$API_TOKEN" ]]; then
  if [[ -f /root/.secrets/cloudflare-certbot.ini ]]; then
    API_TOKEN="$(grep 'dns_cloudflare_api_token' /root/.secrets/cloudflare-certbot.ini | sed 's/.*= *//' | tr -d '\r\n\"')"
  fi
fi

if [[ -z "$API_TOKEN" ]]; then
  echo "ERRO: CLOUDFLARE_API_TOKEN ausente"
  exit 1
fi

if [[ -z "$ZONE_ID" ]]; then
  ZONE_ID=$(curl -sS -G "https://api.cloudflare.com/client/v4/zones" \
    --data-urlencode "name=${ZONE_NAME}" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result',[]); print(r[0]['id'] if r else '')")
fi

if [[ -z "$ZONE_ID" ]]; then
  cat <<EOF
ERRO: zone_id nao encontrado para ${ZONE_NAME}.

Opcao A — painel Cloudflare (30s):
  DNS → Add record → CNAME
  Nome: academia
  Destino: ${TUNNEL_CNAME}
  Proxy: ativado

Opcao B — exporte o zone_id e rode de novo:
  export CLOUDFLARE_ZONE_ID=<id da URL dash.cloudflare.com/.../ZONE_ID/...>
  bash scripts/cloudflare-dns-academia.sh
EOF
  exit 1
fi

existing=$(curl -sS -G "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  --data-urlencode "type=CNAME" \
  --data-urlencode "name=academia" \
  -H "Authorization: Bearer ${API_TOKEN}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result',[]); print(r[0]['id'] if r else '')")

if [[ -n "$existing" ]]; then
  echo "OK: CNAME academia ja existe."
  exit 0
fi

code=$(curl -sS -o /tmp/cf_dns_academia.json -w '%{http_code}' \
  -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"CNAME\",\"name\":\"academia\",\"content\":\"${TUNNEL_CNAME}\",\"proxied\":true}")

if [[ "$code" == "200" ]]; then
  echo "OK: CNAME academia -> ${TUNNEL_CNAME} criado."
else
  echo "ERRO: falha CNAME academia (HTTP ${code})"
  cat /tmp/cf_dns_academia.json
  exit 1
fi
