# libra-automations

Event-driven n8n automations for [Libra](https://github.com/vaoan/Libra), a multi-seller
community marketplace. Self-hosted n8n + Postgres in Docker; runs on macOS and Windows 11.

```
Libra (Supabase Postgres) ──trigger + pg_net──▶ n8n webhook ──▶ Postgres query ──┬──────────────▶ email to seller
                                                                                 └▶ receipt? ─▶ AI check ─┘
AI check (sub-workflow): download from private bucket ─▶ Gemini Flash (structured JSON)
                         ─fallback▶ Gemini Flash-Lite ─▶ compare with order ─▶ ✅ match / ⚠️ review / ❔ unverified
```

## Workflows

| Workflow | Trigger | What it does |
| --- | --- | --- |
| Notify seller | New order / receipt uploaded | Emails the seller the order summary (items, total, transfer number) |
| Verify receipt with AI | Called by *Notify seller* when a receipt is uploaded | Reads the receipt image with Gemini, checks amount and reference against the order, adds a verdict to the email |

The AI check never blocks the notification: if the download or both models fail, the email
still goes out marked "❔ verify manually". The seller always makes the final decision.

## Run locally

```bash
scripts/init-env.sh      # first time: creates .env with generated secrets
docker compose up -d     # n8n → http://localhost:5678, Mailpit → http://localhost:8025
scripts/deploy.sh        # credentials + workflows + webhook registration in Libra
scripts/activate.sh      # publish workflows
scripts/test-order.sh match      # dev: fake order + matching receipt   → ✅
scripts/test-order.sh mismatch   # dev: receipt with the wrong amount  → ⚠️
scripts/test-order.sh missing    # dev: receipt can't be downloaded    → ❔
```

Requires Libra's local Supabase running (`pnpm supabase:docker start --env dev` in the Libra repo).
Libra's code is not modified: `deploy.sh` installs the trigger from `libra-db/order_event_webhooks.sql`
into its database.

## Backup / move to another machine

```bash
scripts/backup.sh --stop
scripts/restore.sh backups/libra-automations-<stamp>.tar.gz   # on the new machine, same .env
```
