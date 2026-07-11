#!/bin/sh
set -eu

API="http://api:8080"
TEST_FILE="/tmp/foco-r2-test3.png"

printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xdb\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEST_FILE"

curl -sS -o /tmp/login3.json -X POST "$API/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"instrutor@academia.com","password":"instrutor123","academySlug":"academia-demo","deviceId":"r2-test3","deviceLabel":"test"}'

TOKEN=$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' /tmp/login3.json)
echo "TOKEN_LEN=${#TOKEN}"

curl -sS -D /tmp/upload3.hdr -o /tmp/upload3.json -w "HTTP=%{http_code}\n" -X POST "$API/api/instructor/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@${TEST_FILE};type=image/png"

echo "BODY=$(cat /tmp/upload3.json)"
