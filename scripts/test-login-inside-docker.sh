#!/bin/sh
curl -sS -X POST http://api:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"instrutor@academia.com","password":"instrutor123","academySlug":"academia-demo","deviceId":"r2-test4","deviceLabel":"test"}'
