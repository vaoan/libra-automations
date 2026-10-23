#!/usr/bin/env bash
# Import credentials (built from .env) and every workflow in workflows/ into n8n,
# then install the trigger (libra-db/) and register the webhook target in Libra's database.
# Safe to re-run: imports overwrite by id, the webhook row is upserted.
set -euo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Credentials are generated here so no secret is ever stored in the repo.
node -e '
const e = process.env;
const creds = [
  { id: "LibraHookSecret1", name: "Libra webhook secret", type: "httpHeaderAuth",
    data: { name: "X-Libra-Webhook-Secret", value: e.LIBRA_WEBHOOK_SECRET } },
  { id: "LibraDbDev000001", name: "Libra DB (dev)", type: "postgres",
    data: { host: e.LIBRA_DB_HOST, port: Number(e.LIBRA_DB_PORT), database: e.LIBRA_DB_NAME,
            user: e.LIBRA_DB_USER, password: e.LIBRA_DB_PASSWORD, ssl: "disable" } },
  { id: "LibraSmtp0000001", name: "SMTP", type: "smtp",
    data: { host: e.SMTP_HOST, port: Number(e.SMTP_PORT), secure: e.SMTP_SECURE === "true",
            user: e.SMTP_USER, password: e.SMTP_PASSWORD, disableStartTls: e.SMTP_SECURE !== "true" } },
  { id: "GeminiApiKey0001", name: "Gemini API key", type: "httpHeaderAuth",
    data: { name: "x-goog-api-key", value: e.GEMINI_API_KEY ?? "" } },
  { id: "LibraStorageDev1", name: "Libra Storage (dev)", type: "httpHeaderAuth",
    data: { name: "apikey", value: e.LIBRA_SUPABASE_SERVICE_KEY ?? "" } },
];
// Optional keys may be managed in the n8n UI instead of .env: when empty here,
// skip the credential so the value saved in n8n is not overwritten.
const optional = { GeminiApiKey0001: "GEMINI_API_KEY", LibraStorageDev1: "LIBRA_SUPABASE_SERVICE_KEY" };
const selected = creds.filter((c) => {
  const key = optional[c.id];
  if (key && !e[key]) {
    console.error(`note: ${key} empty in .env — keeping the "${c.name}" credential as set in the n8n UI`);
    return false;
  }
  return true;
});
process.stdout.write(JSON.stringify(selected));
' > "$tmp/credentials.json"

docker compose cp "$tmp/credentials.json" n8n:/tmp/credentials.json
docker compose exec -T n8n n8n import:credentials --input=/tmp/credentials.json
docker compose exec -T -u root n8n rm -f /tmp/credentials.json

for wf in workflows/*.json; do
  docker compose cp "$wf" n8n:/tmp/workflow.json
  docker compose exec -T n8n n8n import:workflow --input=/tmp/workflow.json
done
docker compose exec -T -u root n8n rm -f /tmp/workflow.json

# Libra's repo is not modified: the trigger SQL lives here and is applied to its database.
for f in libra-db/*.sql; do
  docker exec -i "$LIBRA_DB_CONTAINER" psql -v ON_ERROR_STOP=1 -q -U postgres -d postgres < "$f"
done

docker exec -i "$LIBRA_DB_CONTAINER" psql -v ON_ERROR_STOP=1 -q -U postgres -d postgres \
  -v url="$LIBRA_WEBHOOK_URL" -v secret="$LIBRA_WEBHOOK_SECRET" <<'SQL'
insert into public.integration_webhooks (event, url, secret)
values ('order.created', :'url', :'secret'), ('order.status_changed', :'url', :'secret')
on conflict (event) do update set url = excluded.url, secret = excluded.secret, is_active = true;
SQL

echo "Deployed. Run scripts/activate.sh to publish the workflows."
