#!/usr/bin/env bash
# Publish every workflow in workflows/ and restart n8n so the webhooks go live.
set -euo pipefail
cd "$(dirname "$0")/.."

for wf in workflows/*.json; do
  id=$(node -p "require('./$wf').id")
  docker compose exec -T n8n n8n publish:workflow --id="$id"
done

docker compose restart n8n
until curl -sf http://localhost:5678/healthz >/dev/null; do sleep 2; done
# Webhooks register a few seconds after /healthz is up; 404 means not yet.
until [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:5678/webhook/libra-order-events)" != "404" ]; do sleep 2; done
echo "Workflows published and webhooks are live."
