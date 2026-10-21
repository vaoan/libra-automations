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
  Targets live in Libra table `integration_webhooks` (migration
  `20261021120000_order_event_webhooks.sql`, branch `feat/GH-000_n8n-order-webhook`).
- Payload is ids + status only; workflows read details with their own DB credential.

## Workflows (`workflows/*.json`, source of truth)
1. `order-notify-seller.json` — email the seller on `order.created` and when a
   receipt is uploaded (`pending_verification`).

## Scripts
- `scripts/init-env.sh` — first machine only, creates `.env` with secrets.
- `scripts/deploy.sh` — builds credentials from `.env`, imports workflows, registers the webhook in Libra.
- `scripts/activate.sh` — publishes workflows, restarts n8n, waits until webhooks are live.
- `scripts/test-order.sh` — DEV ONLY: fake order → shows pg_net deliveries + Mailpit inbox.
- `scripts/backup.sh` / `scripts/restore.sh` — migration between machines (Git Bash on Windows).

## Rules
- Edit workflows in the JSON files, then `deploy.sh` + `activate.sh`. If edited in the UI,
  export back to `workflows/` so git stays the source of truth.
- Never commit `.env`. `N8N_ENCRYPTION_KEY` must be identical across machines.
- Libra repo rules apply there: ask before git branch/commit/push (see its `.claude/rules/git-safety.md`).
- Dev data uses `example.com` addresses only; never point dev scripts at Libra prod.
- Planned next: AI receipt check (vision), stale-order reminders (cron), weekly sales report.
