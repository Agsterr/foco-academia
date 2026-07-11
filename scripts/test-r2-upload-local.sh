#!/bin/bash
set -eu

API="http://127.0.0.1"
HOST="academia.focodev.com.br"
TEST_FILE="/tmp/foco-r2-test2.png"

printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xdb\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEST_FILE"

curl -sS -o /tmp/login2.json -X POST "$API/api/auth/login" \
  -H "Host: $HOST" \
  -H "Content-Type: application/json" \
  -d '{"email":"instrutor@academia.com","password":"instrutor123","academySlug":"academia-demo","deviceId":"r2-test2","deviceLabel":"test"}'

TOKEN=$(python3 -c 'import json; print(json.load(open("/tmp/login2.json"))["token"])')

echo "Calling API container directly via nginx..."
curl -sS -D /tmp/upload-headers.txt -o /tmp/upload2.json -X POST "$API/api/instructor/media" \
  -H "Host: $HOST" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@${TEST_FILE};type=image/png"

echo
cat /tmp/upload2.json
echo
cat /tmp/upload-headers.txt

echo "Recent API logs:"
docker logs foco-academia-api 2>&1 | tail -5
