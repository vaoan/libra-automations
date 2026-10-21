# libra-automations — project context

n8n automations around **Libra** (multi-seller marketplace, repo `~/Documents/GitHub/Libra`).
Self-hosted n8n Community in Docker, $0/month. Portfolio project for n8n experience.

## Language
- Chat with the user in Spanish; code, commits, logs and workflow content in English.
- Emails/messages to Libra users are in Spanish.

## Architecture
- `docker-compose.yml`: n8n (127.0.0.1:5678) + Postgres 17 + Mailpit (dev inbox, :8025).
- Libra's dev Supabase runs from the Libra repo: `pnpm supabase:docker start --env dev`
  (API :54331, DB :54332, Studio :54333). n8n reaches it via `host.docker.internal`.
- Event flow: Libra `orders` trigger `orders_notify_event` → `pg_net` POST →
  n8n webhook `/webhook/libra-order-events` (header `X-Libra-Webhook-Secret`).
  Targets live in Libra table `integration_webhooks`. The SQL is in `libra-db/` and
  `deploy.sh` applies it to Libra's database — **never modify the Libra repo**.
- Payload is ids + status only; workflows read details with their own DB credential.

## Workflows (`workflows/*.json`, source of truth)
1. `order-notify-seller.json` — email the seller on `order.created` and when a
   receipt is uploaded (`pending_verification`); for receipts it calls workflow 2 first.
2. `verify-receipt-ai.json` — sub-workflow: download receipt (private `receipts` bucket,
   `apikey` = local Supabase secret key) → Gemini `gemini-flash-latest` structured JSON →
   fallback `gemini-flash-lite-latest` → compare amount/reference → `receipt_check`
   {match|review|unverified}. Must never throw: every path ends in "Compare with order".
   Gemini keys start with `AQ.` (new format); `gemini-2.5-*` is not available to this account.
3. `stale-order-reminder.json` — cron 9:00 + manual trigger: `pending_verification` orders whose
   `expires_at` falls in the next 24 h, one email per seller (daily window = no "sent" state).
4. `weekly-sales-report.json` — cron Monday 8:00 + manual trigger: per seller/currency funnel,
   revenue, top 3 products; Gemini Flash-Lite 3-line summary (optional, report sends without it).
5. `error-alert.json` — Error Trigger → email `ADMIN_EMAIL`. All other workflows set
   `settings.errorWorkflow = LibraErrorAlert1`.

## Scripts
- `scripts/init-env.sh` — first machine only, creates `.env` with secrets.
- `scripts/deploy.sh` — builds credentials from `.env`, imports workflows, installs `libra-db/` SQL and registers the webhook in Libra's DB.
- `scripts/activate.sh` — publishes workflows, restarts n8n, waits until webhooks are live.
- `scripts/test-order.sh [match|mismatch|missing]` — DEV ONLY: fake order + receipt upload →
  shows pg_net deliveries + Mailpit inbox. Fixtures from `scripts/make-fixtures.sh` (Chrome headless).
- Optional keys (`GEMINI_API_KEY`, `LIBRA_SUPABASE_SERVICE_KEY`) may be set in the n8n UI
  instead; `deploy.sh` skips them when empty so the UI value is kept.
- `scripts/backup.sh` / `scripts/restore.sh` — migration between machines (Git Bash on Windows).

## Rules
- Edit workflows in the JSON files, then `deploy.sh` + `activate.sh`. If edited in the UI,
  export back to `workflows/` so git stays the source of truth.
- Never commit `.env`. `N8N_ENCRYPTION_KEY` must be identical across machines.
- Do not create branches, files or commits in the Libra repo; it is read-only for this project.
- Dev data uses `example.com` addresses only; never point dev scripts at Libra prod.
- `scripts/run-workflow.sh <id>` runs a workflow via CLI; it needs `N8N_RUNNERS_BROKER_PORT=5690`
  because the running n8n holds 5679. `scripts/dev-demo-week.sql` approves/ages fake orders for demos.
- Scope: only this repo and Libra's data. No Telegram/Sheets or other outside channels unless asked.
