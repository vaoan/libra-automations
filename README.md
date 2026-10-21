# libra-automations

**n8n automations for [Libra](https://github.com/vaoan/Libra)**, a multi-seller marketplace for
communities where buyers pay by bank transfer and upload a screenshot as proof of payment.
These workflows take the manual follow-up off the sellers: they get told about new orders,
receipts are pre-checked by AI, nothing expires unnoticed, and every Monday they get their numbers.

Self-hosted n8n + Postgres in Docker. Runs on macOS and Windows 11. **$0/month** to operate.

## What it automates

| # | Workflow | Trigger | What it does |
| --- | --- | --- | --- |
| 1 | **Notify seller** | Libra DB event (new order, receipt uploaded) | Emails the seller the order: items, total, transfer number |
| 2 | **Verify receipt with AI** | Sub-workflow of #1 | Reads the receipt image with Gemini and checks amount + reference against the order → ✅ / ⚠️ / ❔ |
| 3 | **Receipt expiry reminder** | Daily 9:00 (cron) | Warns sellers about receipts that Libra will auto-expire within 24 h |
| 4 | **Weekly sales report** | Mondays 8:00 (cron) | Per-seller funnel, revenue, top products + a 3-line AI summary |
| 5 | **Failure alerts** | n8n Error Trigger | Emails the admin the failed node, error and a link to the execution |

## Architecture

```
                       ┌───────────────────────── n8n (Docker) ─────────────────────────┐
Libra Postgres         │                                                                │
 orders trigger ─pg_net─▶ Webhook ─▶ Load order ─▶ Receipt? ─yes─▶ Verify receipt (AI) ─┐ │
 (secret header)       │                              └──no────────────────────────────┴▶ Email seller
                       │                                                                │
                       │  Verify receipt: download (private bucket) ─▶ Gemini Flash      │
                       │                  ─fail▶ Gemini Flash-Lite ─▶ compare with order │
                       │                                                                │
                       │  Cron 9:00 ─▶ receipts expiring < 24 h ─▶ reminder per seller   │
                       │  Cron Mon 8:00 ─▶ weekly stats ─▶ AI summary ─▶ report email    │
                       │  Any failure ─▶ Error Trigger ─▶ alert to admin                 │
                       └────────────────────────────────────────────────────────────────┘
```

## Design decisions

- **Events from the database, not polling.** A Postgres trigger on `orders` calls n8n through
  `pg_net` after commit, so notifications are instant and a failed webhook never blocks a checkout.
- **Thin payload.** The webhook carries ids and status only; n8n reads the details with its own
  database credential. Nothing sensitive travels in the event, and the receiver always sees
  committed data. The webhook is authenticated with a shared-secret header.
- **AI assists, never decides.** Gemini returns structured JSON (`responseSchema`), the comparison
  with the order is plain code, and every failure path (download error, model overloaded, bad JSON)
  ends in an "❔ verify manually" email. Flash falls back to Flash-Lite automatically.
- **No state to keep.** The reminder runs daily over a 24 h window, so each order is reminded once
  without storing "already sent" flags.
- **Libra stays untouched.** The trigger SQL lives here (`libra-db/`) and `deploy.sh` installs it;
  Libra's repository is never modified.
- **Workflows as code.** `workflows/*.json` is the source of truth; credentials are generated from
  `.env` at deploy time, so no secret is ever committed.

## Run locally

```bash
scripts/init-env.sh      # first time: creates .env with generated secrets
docker compose up -d     # n8n → http://localhost:5678, Mailpit (dev inbox) → http://localhost:8025
scripts/deploy.sh        # credentials + workflows + trigger installed in Libra's DB
scripts/activate.sh      # publish workflows
```

Requires Libra's local Supabase running (`pnpm supabase:docker start --env dev` in the Libra repo).

### Try it

```bash
scripts/test-order.sh match           # fake order + matching receipt  → ✅ email
scripts/test-order.sh mismatch        # receipt with the wrong amount  → ⚠️ email
scripts/test-order.sh missing         # receipt can't be downloaded    → ❔ email
scripts/test-order.sh match live      # same, but watch it on the n8n canvas (click "Execute" first)
scripts/run-workflow.sh LibraStaleRemind1   # run the daily reminder now
scripts/run-workflow.sh LibraWeeklyRpt01    # run the weekly report now
```

Test receipts are rendered from `tests/fixtures/receipt.html` (fictional bank) by `scripts/make-fixtures.sh`.

## Backup / move to another machine

```bash
scripts/backup.sh --stop
scripts/restore.sh backups/libra-automations-<stamp>.tar.gz   # on the new machine, same .env
```

## Stack

n8n 2.x (self-hosted, Docker) · PostgreSQL 17 · Supabase (Postgres, Storage, `pg_net`) ·
Google Gemini (multimodal, structured output) · SMTP / Mailpit · Bash
