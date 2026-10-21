# CV entry and interview notes

Everything below is true for this repository as built and tested end-to-end against
Libra's development environment. Add usage numbers only once it runs in production.

## Español

**Automatización de procesos con n8n — Libra** (marketplace multivendedor) · 2026
- Diseñé e implementé 5 workflows en n8n self-hosted (Docker + PostgreSQL) que automatizan el
  seguimiento de pedidos de Libra: avisos a vendedores, verificación de pagos, recordatorios y reportes.
- Integración event-driven: triggers de PostgreSQL con `pg_net` llaman webhooks autenticados de n8n
  en cuanto se crea un pedido o se sube un comprobante.
- Verificación de comprobantes de pago con IA multimodal (Google Gemini, salida JSON estructurada),
  con failover entre modelos y validación de monto y referencia contra el pedido.
- Workflows programados (cron): recordatorio de comprobantes por vencer y reporte semanal de ventas
  por vendedor con resumen generado por IA.
- Manejo de errores con Error Workflow y alertas al administrador; sub-workflows reutilizables y
  rutas de fallo no bloqueantes.
- Workflows versionados como código, despliegue y pruebas automatizadas por script, backups y
  migración entre macOS y Windows; costo operativo $0.
- github.com/vaoan/libra-automations

## English

**Workflow Automation with n8n — Libra** (multi-seller marketplace) · 2026
- Designed and built 5 self-hosted n8n workflows (Docker + PostgreSQL) automating Libra's order
  follow-up: seller notifications, payment verification, reminders and reporting.
- Event-driven integration: PostgreSQL triggers (`pg_net`) call authenticated n8n webhooks when an
  order is created or a receipt is uploaded.
- AI payment-receipt verification with multimodal Google Gemini (structured JSON output), model
  failover and amount/reference validation against the order.
- Scheduled workflows: expiring-receipt reminders and weekly per-seller sales reports with an AI summary.
- Error Workflow alerting, reusable sub-workflows and non-blocking failure paths.
- Workflows as code with scripted deploy, end-to-end tests, backups and macOS/Windows portability; $0 to run.

## Skills to list

n8n (webhooks, sub-workflows, Schedule/Error triggers, Code node, HTTP Request, Postgres, Email) ·
PostgreSQL (triggers, `pg_net`, SQL reporting) · Supabase · LLM integration (Gemini, structured
output, fallback) · Docker / Docker Compose · Bash · JavaScript

## Interview talking points

1. **Why a database trigger instead of polling?** Instant, no wasted executions, and `pg_net`
   sends after commit so a slow or down n8n never blocks a checkout.
2. **Why is the webhook payload only ids?** No personal data in transit; n8n reads committed data
   with its own credential; the event can't be spoofed into wrong content (shared-secret header).
3. **How do you keep the AI from causing damage?** It only adds a verdict. Structured output with a
   schema, deterministic comparison in code, fallback model, and every failure still sends the email
   marked "verify manually". The seller approves.
4. **How do you avoid duplicate reminders without state?** Daily run over a 24 h expiry window.
5. **How is it deployed and tested?** Workflows are JSON in git; `deploy.sh` generates credentials
   from `.env`, imports and publishes; `test-order.sh` drives real orders through the database and
   checks the inbox; three receipt scenarios (match / mismatch / missing).
6. **What would you do for production?** Point the Postgres/Storage credentials at production with
   a read-only DB role, real SMTP, run n8n 24/7 with backups, and use the Error Workflow alerts.

## Demo checklist (2-minute video)

1. Show the five workflows in n8n.
2. Click **Execute** on "Notify seller", run `scripts/test-order.sh mismatch live`, watch the canvas turn green.
3. Open the ⚠️ email in Mailpit and the AI sub-workflow execution (Gemini output).
4. Run the weekly report (`scripts/run-workflow.sh LibraWeeklyRpt01`) and show the email.
