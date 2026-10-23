-- Audit log of automatic receipt checks (written by the n8n "Verify receipt" sub-workflow).
--
-- Two uses: a trail of what the automation told each seller, and the memory needed to spot a
-- receipt reused across orders (same file, or same reference printed on it).
-- Data minimization: no images, names or account numbers — only a file hash, the normalized
-- reference, the amount read and the verdict. Rows are purged after 12 months.

CREATE TABLE IF NOT EXISTS "public"."integration_receipt_checks" (
    "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    "order_id" "uuid" NOT NULL,
    "file_sha256" "text",
    "transfer_ref_norm" "text",
    "extracted_amount" numeric,
    "status" "text" NOT NULL,
    "reasons" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "model" "text",
    "checked_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "integration_receipt_checks_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "integration_receipt_checks_order_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE,
    CONSTRAINT "integration_receipt_checks_status_check" CHECK (("status" = ANY (ARRAY['match'::"text", 'review'::"text", 'unverified'::"text"])))
);

ALTER TABLE "public"."integration_receipt_checks" OWNER TO "postgres";

COMMENT ON TABLE "public"."integration_receipt_checks" IS 'Automatic receipt checks sent to sellers (n8n). Advisory only; never changes an order. RLS on, no policies, service role only.';

CREATE INDEX IF NOT EXISTS "integration_receipt_checks_order_idx" ON "public"."integration_receipt_checks" ("order_id");
CREATE INDEX IF NOT EXISTS "integration_receipt_checks_file_idx" ON "public"."integration_receipt_checks" ("file_sha256") WHERE "file_sha256" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "integration_receipt_checks_ref_idx" ON "public"."integration_receipt_checks" ("transfer_ref_norm") WHERE "transfer_ref_norm" IS NOT NULL;

-- No policies: only the service role / table owner can read or write.
ALTER TABLE "public"."integration_receipt_checks" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE "public"."integration_receipt_checks" FROM "anon", "authenticated";


-- Retention: called daily by the n8n reminder workflow.
CREATE OR REPLACE FUNCTION "public"."purge_integration_receipt_checks"() RETURNS integer
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with deleted as (
    delete from public.integration_receipt_checks
    where checked_at < now() - interval '12 months'
    returning 1
  )
  select count(*)::integer from deleted;
$$;

ALTER FUNCTION "public"."purge_integration_receipt_checks"() OWNER TO "postgres";

REVOKE ALL ON FUNCTION "public"."purge_integration_receipt_checks"() FROM PUBLIC, "anon", "authenticated";
