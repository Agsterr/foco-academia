#!/bin/bash
set -euo pipefail

API="${API:-https://academia.focodev.com.br}"
R2_BASE="${R2_BASE:-https://pub-980d61b3528342859e3122c243d2800b.r2.dev}"
TEST_FILE="/tmp/foco-r2-test.png"

printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xdb\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEST_FILE"

LOGIN=$(curl -sS -X POST "$API/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"instrutor@academia.com","password":"instrutor123","academySlug":"academia-demo","deviceId":"r2-test-script","deviceLabel":"R2 test"}')

TOKEN=$(echo "$LOGIN" | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

RESP=$(curl -sS -X POST "$API/api/instructor/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@${TEST_FILE};type=image/png")

echo "UPLOAD_RESPONSE=$RESP"

URL=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["url"])')
echo "MEDIA_URL=$URL"

case "$URL" in
  "$R2_BASE"*) echo "R2_URL_PREFIX=OK" ;;
  *) echo "R2_URL_PREFIX=FALHOU"; exit 1 ;;
esac

HTTP=$(curl -sS -o /dev/null -w "%{http_code}" "$URL")
echo "PUBLIC_HTTP=$HTTP"

if [ "$HTTP" != "200" ]; then
  echo "PUBLIC_ACCESS=FALHOU"
  exit 1
fi

echo "TESTE_R2=SUCESSO"
