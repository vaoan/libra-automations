#!/usr/bin/env bash
# DEV ONLY: create a test order in Libra's local DB and show what n8n did with it.
set -euo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

docker exec -i "$LIBRA_DB_CONTAINER" psql -v ON_ERROR_STOP=1 -q -U postgres -d postgres < scripts/dev-test-order.sql >/dev/null
sleep 5

echo "Webhook deliveries (pg_net, latest first):"
docker exec "$LIBRA_DB_CONTAINER" psql -U postgres -d postgres -Atc \
  "select id, status_code, coalesce(error_msg, '') from net._http_response order by created desc limit 2;"

echo "Emails in Mailpit (http://localhost:8025):"
curl -s "http://localhost:8025/api/v1/messages?limit=5" | node -e '
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
  for (const m of JSON.parse(s).messages) console.log(`- ${m.To[0].Address}: ${m.Subject}`);
});'
