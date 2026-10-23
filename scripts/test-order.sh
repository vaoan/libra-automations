#!/usr/bin/env bash
# DEV ONLY: run a fake order through the same steps as the real checkout and show
# what n8n did with it.
#   1. create the order (fires order.created)
#   2. upload a receipt image to the private receipts bucket
#   3. move the order to pending_verification (fires order.status_changed → AI check)
# Usage: scripts/test-order.sh [match|mismatch|missing|reused]   (default: match)
#   missing: no file is uploaded, so the AI check must fall back to "unverified".
#   reused: run after "match" — uploads the same receipt again, so it must be flagged as reused.
# Every other variant first clears earlier test orders' references and checks, so the fixed
# reference printed on the fixtures does not count as reused.
# Add "live" as 2nd arg to watch it on the n8n canvas: first click "Execute" in the
# editor, then run e.g. scripts/test-order.sh match live — the receipt event goes to
# the editor's test listener (/webhook-test/) instead of the published webhook.
set -euo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

variant=${1:-match}
fixture="tests/fixtures/receipt-${variant/reused/match}.png"
[ "$variant" = missing ] || [ -f "$fixture" ] || { echo "Missing $fixture — run scripts/make-fixtures.sh" >&2; exit 1; }
[ -n "${LIBRA_SUPABASE_SERVICE_KEY:-}" ] || { echo "LIBRA_SUPABASE_SERVICE_KEY is empty in .env" >&2; exit 1; }

sql() { docker exec -i "$LIBRA_DB_CONTAINER" psql -v ON_ERROR_STOP=1 -qAt -U postgres -d postgres "$@"; }
# From the host, the Supabase API is on localhost (n8n uses host.docker.internal).
supabase_url=${LIBRA_SUPABASE_URL/host.docker.internal/localhost}

sql < scripts/dev-test-order.sql >/dev/null
if [ "$variant" != reused ]; then
  sql >/dev/null <<'SQL'
delete from public.integration_receipt_checks where order_id in (select id from public.orders where seller_id = '00000000-0000-4000-a000-000000000001');
update public.orders set transfer_number = null where seller_id = '00000000-0000-4000-a000-000000000001' and transfer_number = 'TEST-123456';
SQL
fi
order_id=$(sql <<'SQL'
-- created_at = the date printed on the fixtures, so the "receipt older than the order" check passes.
with new_order as (
  insert into public.orders (user_id, seller_id, total, currency, payment_status, transfer_number, created_at)
  values ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000001', 50000, 'COP', 'awaiting_payment', 'TEST-123456', '2026-10-21 08:00:00-05')
  returning id
), item as (
  insert into public.order_items (order_id, product_id, quantity, unit_price, currency)
  select id, '00000000-0000-4000-b000-000000000001', 2, 25000, 'COP' from new_order
)
select id from new_order;
SQL
)
echo "Order $order_id created ($variant receipt)"

path="$order_id/receipt.png"
if [ "$variant" = missing ]; then
  echo "No receipt uploaded (testing the failure path)"
else
  curl -sf -X POST "$supabase_url/storage/v1/object/receipts/$path" \
    -H "apikey: $LIBRA_SUPABASE_SERVICE_KEY" -H "Content-Type: image/png" \
    --data-binary "@$fixture" >/dev/null
  echo "Receipt uploaded to receipts/$path"
fi

sleep 2
if [ "${2:-}" = live ]; then
  # The trigger reads the URL when it fires, so switching it around the update is enough.
  sql -c "update public.integration_webhooks set url = replace(url, '/webhook/', '/webhook-test/') where event = 'order.status_changed';"
  sql -c "update public.orders set payment_status = 'pending_verification', receipt_url = '$path' where id = '$order_id';"
  sql -c "update public.integration_webhooks set url = replace(url, '/webhook-test/', '/webhook/') where event = 'order.status_changed';"
  echo "Receipt event sent to the editor — watch the canvas in n8n."
else
  sql -c "update public.orders set payment_status = 'pending_verification', receipt_url = '$path' where id = '$order_id';"
fi

echo "Waiting for n8n (AI check can take ~10-20 s)..."
for _ in $(seq 1 30); do
  sleep 2
  count=$(curl -s "http://localhost:${MAILPIT_PORT:-8025}/api/v1/search?query=${order_id:0:8}" | node -pe 'JSON.parse(require("fs").readFileSync(0)).messages_count')
  [ "$count" -ge 2 ] && break
done

echo "Webhook deliveries (pg_net, latest first):"
sql -c "select id, status_code, coalesce(error_msg, '') from net._http_response order by created desc limit 2;"

echo "Emails for this order in Mailpit (http://localhost:${MAILPIT_PORT:-8025}):"
curl -s "http://localhost:${MAILPIT_PORT:-8025}/api/v1/search?query=${order_id:0:8}" | node -e '
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
  for (const m of JSON.parse(s).messages) console.log(`- ${m.To[0].Address}: ${m.Subject}`);
});'
