# libra-automations

Event-driven n8n automations for [Libra](https://github.com/vaoan/Libra), a multi-seller
community marketplace. Self-hosted n8n + Postgres in Docker; runs on macOS and Windows 11.

```
Libra (Supabase Postgres) ──trigger + pg_net──▶ n8n webhook ──▶ Postgres query ──▶ email to seller
```

## Workflows

| Workflow | Trigger | What it does |
| --- | --- | --- |
| Notify seller | New order / receipt uploaded | Emails the seller the order summary (items, total, transfer number) |

## Run locally

```bash
scripts/init-env.sh      # first time: creates .env with generated secrets
docker compose up -d     # n8n → http://localhost:5678, Mailpit → http://localhost:8025
scripts/deploy.sh        # credentials + workflows + webhook registration in Libra
scripts/activate.sh      # publish workflows
scripts/test-order.sh    # dev: create a fake order and see the emails
```

Requires Libra's local Supabase running (`pnpm supabase:docker start --env dev` in the Libra repo)
with the `order_event_webhooks` migration applied.

## Backup / move to another machine

```bash
scripts/backup.sh --stop
scripts/restore.sh backups/libra-automations-<stamp>.tar.gz   # on the new machine, same .env
```
