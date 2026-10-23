# Receipt verification — what it does, what it cannot do, and the rules around it

Libra sellers who accept bank transfers (Nequi, Daviplata, bank accounts) ask buyers to upload a
receipt. The receipt is an image the buyer controls. The automation pre-checks it so the seller
looks closely where it matters. It does **not** confirm payments.

## The one rule

**A receipt is not proof of payment. Only the money in the seller's account is.** Before approving
an order, the seller opens their bank or wallet and confirms the incoming transfer (amount and
reference). Every receipt email says this, whatever the verdict.

## What the automation checks

| Check | How | Catches |
|---|---|---|
| Is it a payment receipt? | Gemini (structured JSON) | Random images, screenshots of the cart |
| Amount = order total | Code | Partial payments, receipts from other purchases |
| Currency = order currency | Code (only when an ISO code is printed) | Payments in the wrong currency |
| Printed reference = reference the buyer typed | Code | Typos, receipts from other purchases |
| Receipt date ≥ order date, not in the future | Code (America/Bogota) | Old receipts reused for a new order |
| Reference already used in another order | Libra DB + audit log | The same transfer claimed twice (any seller) |
| Same file already uploaded for another order | SHA-256 of the file + audit log | Re-uploading the exact same image |
| Destination account = seller's payment details | Last 4 digits vs. numbers in the payment method text | Money sent to someone else |

Verdicts: ✅ data matches · ⚠️ review (each reason listed) · ❔ could not check (AI or download
failed). A concrete red flag (reused reference/file) turns ❔ into ⚠️.

## What it cannot catch

- **A well-made fake** (edited amount, invented reference that was never reused). An image model
  reads pixels; it cannot ask the bank whether the transfer happened.
- **A re-screenshot or crop** of an old receipt with a reference the system has never seen.
- Destination accounts the seller did not write in the payment method text.

These are exactly what the bank check in "the one rule" covers.

## Safeguards

- **Advisory only.** Nothing writes to orders; the seller approves or rejects in Studio. No
  automated decision is taken about a buyer.
- **Deterministic decisions.** The AI only extracts fields; every comparison is plain code. The
  prompt treats the image as untrusted (text in the image cannot change the verdict logic), and
  everything shown in the email is HTML-escaped.
- **Never blocks.** Download, model, history or audit failures all end in an email.
- **Data minimization.** The audit table (`integration_receipt_checks`) stores a file hash, the
  normalized reference, the amount read, the verdict and its reasons — no images, names or account
  numbers. Emails show only the last 4 digits of the destination account.
- **Retention.** Audit rows are purged after 12 months (daily, by the reminder workflow).
  Execution data in n8n is pruned after 7 days (`EXECUTIONS_DATA_MAX_AGE=168`).
- **Access.** The audit table has RLS on with no policies (service role only); emails go only to
  the seller of that order.

## Legal checklist before production (Colombia)

Not legal advice — confirm with counsel. Points that apply to this flow:

1. **Personal data (Ley 1581 de 2012, Decreto 1074 de 2015).** Receipts contain names and account
   numbers. Libra is the data controller (*responsable*); Google, processing the image, is a
   processor (*encargado*) abroad. Libra's privacy policy must say receipts are processed by an AI
   provider to check payments, and the provider relationship must be covered by a data processing
   agreement (*contrato de transmisión*).
2. **Use a paid Gemini API project in production.** On the free tier, Google's Gemini API terms
   allow using submitted content to improve its products, including human review. That is not
   acceptable for buyers' personal data. A billing-enabled project costs well under a cent per
   receipt. Keep the free key for development with fake receipts only.
3. **Consumer protection (Ley 1480 de 2011).** A ⚠️ is a reason to look, not to reject. Rejections
   should rest on the bank check, and the buyer should be told why (Libra's "evidence requested"
   flow exists for that).
4. **Retention.** Keep the 12-month audit window unless counsel asks otherwise; the orders
   themselves stay in Libra under its own retention.

## Going further (outside this repo)

Manual transfers with uploaded receipts will always need a human bank check. The industry fix is a
**payment gateway** (e.g. Wompi, Bold, Mercado Pago, PSE through a gateway) whose signed webhook
confirms the payment, so no receipt is needed. That is a Libra checkout change; once it exists,
n8n can consume the gateway webhook the same way it consumes order events today.
