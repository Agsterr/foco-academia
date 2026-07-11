#!/bin/bash
docker exec foco-academia-api ls -la /app/uploads 2>/dev/null || true
docker exec foco-academia-api sh -c 'strings /app/app.jar | grep uploadToR2 | head'
