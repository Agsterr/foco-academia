#!/bin/bash
set -eu

API="https://academia.focodev.com.br"
TEST_FILE="/tmp/foco-r2-test.png"

printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xdb\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEST_FILE"

LOGIN_HTTP=$(curl -sS -o /tmp/login.json -w "%{http_code}" -X POST "$API/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"instrutor@academia.com","password":"instrutor123","academySlug":"academia-demo","deviceId":"r2-test-script","deviceLabel":"R2 test"}')
echo "LOGIN_HTTP=$LOGIN_HTTP"
cat /tmp/login.json
echo

TOKEN=$(python3 -c 'import json; print(json.load(open("/tmp/login.json"))["token"])')

UPLOAD_HTTP=$(curl -sS -o /tmp/upload.json -w "%{http_code}" -X POST "$API/api/instructor/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@${TEST_FILE};type=image/png")
echo "UPLOAD_HTTP=$UPLOAD_HTTP"
cat /tmp/upload.json
echo
