-- Outbound webhooks for order events (consumed by n8n automations).
--
-- Rows in integration_webhooks are configured per environment; with no active
-- row for an event the trigger is a no-op. The payload is intentionally small
-- (ids + status); the receiver reads details with its own database credentials.

CREATE TABLE IF NOT EXISTS "public"."integration_webhooks" (
    "event" "text" NOT NULL,
    "url" "text" NOT NULL,
    "secret" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "integration_webhooks_pkey" PRIMARY KEY ("event"),
    CONSTRAINT "integration_webhooks_event_check" CHECK (("event" = ANY (ARRAY['order.created'::"text", 'order.status_changed'::"text"]))),
    CONSTRAINT "integration_webhooks_url_check" CHECK (("url" ~* '^https?://'::"text"))
);

ALTER TABLE "public"."integration_webhooks" OWNER TO "postgres";

COMMENT ON TABLE "public"."integration_webhooks" IS 'Outbound webhook targets per order event. Holds secrets: RLS on, no policies, service role only.';

-- No policies: only the service role / table owner can read or write.
ALTER TABLE "public"."integration_webhooks" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE "public"."integration_webhooks" FROM "anon", "authenticated";

CREATE OR REPLACE TRIGGER "integration_webhooks_set_updated_at"
    BEFORE UPDATE ON "public"."integration_webhooks"
    FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_updated_at"();


CREATE OR REPLACE FUNCTION "public"."notify_order_event"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_event text;
  v_hook record;
begin
  if tg_op = 'INSERT' then
    v_event := 'order.created';
  elsif new.payment_status is distinct from old.payment_status then
    v_event := 'order.status_changed';
  else
    return new;
  end if;

  select url, secret into v_hook
  from public.integration_webhooks
  where event = v_event and is_active;

  if not found then
    return new;
  end if;

  -- pg_net queues the request and sends it after commit; failures never block the order.
  perform net.http_post(
    url := v_hook.url,
    body := jsonb_build_object(
      'event', v_event,
      'order_id', new.id,
      'seller_id', new.seller_id,
      'payment_status', new.payment_status,
      'previous_status', case when tg_op = 'UPDATE' then old.payment_status end,
      'occurred_at', now()
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Libra-Webhook-Secret', v_hook.secret
    )
  );

  return new;
end;
$$;

ALTER FUNCTION "public"."notify_order_event"() OWNER TO "postgres";

REVOKE ALL ON FUNCTION "public"."notify_order_event"() FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE TRIGGER "orders_notify_event"
    AFTER INSERT OR UPDATE OF "payment_status" ON "public"."orders"
    FOR EACH ROW EXECUTE FUNCTION "public"."notify_order_event"();
