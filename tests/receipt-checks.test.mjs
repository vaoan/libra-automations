// Offline tests for the receipt-check Code nodes: runs the jsCode stored in workflows/*.json
// with a stubbed n8n context. No n8n, database or Gemini needed: node --test tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const verify = JSON.parse(readFileSync(new URL('../workflows/verify-receipt-ai.json', import.meta.url)));
const notify = JSON.parse(readFileSync(new URL('../workflows/order-notify-seller.json', import.meta.url)));
const code = (wf, name) => wf.nodes.find((n) => n.name === name).parameters.jsCode;

// Runs a Code node: `nodes` are the outputs of earlier nodes, reachable through $('name').
function run(wf, name, input, nodes = {}) {
  const $ = (node) => {
    if (!(node in nodes)) throw new Error(`Node '${node}' hasn't been executed`);
    return { first: () => ({ json: nodes[node] }) };
  };
  const $input = { first: () => ({ json: input, binary: { receipt: { mimeType: 'image/png' } } }), all: () => [{ json: input }] };
  const ctx = { helpers: { getBinaryDataBuffer: async () => Buffer.from('fake receipt image') } };
  return new AsyncFunction('$', '$input', '$json', 'require', code(wf, name)).call(ctx, $, $input, input, require);
}

const order = {
  id: '11111111-2222-4333-8444-555555555555',
  payment_status: 'pending_verification',
  total: 50000,
  currency: 'COP',
  transfer_number: 'TEST-123456',
  receipt_url: 'x/receipt.png',
  created_at: '2026-10-20T15:00:00.000Z',
};
const gemini = (extracted) => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(extracted) }] } }], modelVersion: 'gemini-test' });
const good = { is_payment_receipt: true, amount: 50000, currency: 'COP', transfer_number: 'TEST-123456', date: '2026-10-20', bank: 'Banco', recipient: 'Tienda', recipient_account: '***4567' };

async function check(extracted, history = {}, input = order) {
  const built = (await run(verify, 'Build Gemini request', {}))[0].json;
  const response = extracted === undefined ? { error: 'download failed' } : gemini(extracted);
  const compared = (await run(verify, 'Compare with order', response, { 'Receipt input': input, 'Build Gemini request': built }))[0].json;
  const final = (await run(verify, 'Final verdict', history, { 'Compare with order': compared }))[0].json;
  const returned = (await run(verify, 'Return verdict', { id: 1 }, { 'Final verdict': final }))[0].json;
  return { built, compared, final, returned, check: returned.receipt_check };
}

const methodText = 'Nequi 300 123 4567 a nombre de Tienda de prueba';

test('matching receipt is "match" and only the last 4 account digits leave the workflow', async () => {
  const r = await check(good, { method_text: methodText, reused_reference: [], reused_file: [] });
  assert.equal(r.check.status, 'match', r.check.reasons.join('; '));
  assert.equal(r.check.extracted.recipient_account, '***4567');
  assert.match(r.built.file_sha256, /^[0-9a-f]{64}$/);
  assert.equal(r.final.audit.transfer_ref_norm, 'TEST123456');
  assert.equal(r.returned.audit, undefined);
  assert.equal(r.returned.declared_ref, undefined);
});

test('wrong amount is flagged', async () => {
  const r = await check({ ...good, amount: 45000 });
  assert.equal(r.check.status, 'review');
  assert.ok(r.check.reasons.some((x) => x.includes('monto')));
});

test('receipt dated before the order is flagged as possibly from another purchase', async () => {
  const r = await check({ ...good, date: '2026-10-01' });
  assert.equal(r.check.status, 'review');
  assert.ok(r.check.reasons.some((x) => x.includes('otra compra')));
});

test('missing date and other currency are flagged', async () => {
  const r = await check({ ...good, date: null, currency: 'USD' });
  assert.equal(r.check.status, 'review');
  assert.ok(r.check.reasons.some((x) => x.includes('fecha')));
  assert.ok(r.check.reasons.some((x) => x.includes('USD')));
});

test('reference already used in another order is flagged', async () => {
  const r = await check(good, { reused_reference: [{ id: '99999999-0000-4000-8000-000000000000', status: 'approved' }], reused_file: [] });
  assert.equal(r.check.status, 'review');
  assert.ok(r.check.reasons.some((x) => x.includes('#99999999')));
});

test('same file uploaded for another order is flagged once even if the reference also matches', async () => {
  const other = '88888888-0000-4000-8000-000000000000';
  const r = await check(good, { reused_reference: [{ id: other, status: 'pending_verification' }], reused_file: [other] });
  assert.equal(r.check.reasons.filter((x) => x.includes('#88888888')).length, 1);
  const r2 = await check(good, { reused_reference: [], reused_file: [other] });
  assert.ok(r2.check.reasons.some((x) => x.includes('mismo archivo')));
});

test('money sent to another account is flagged', async () => {
  const r = await check({ ...good, recipient_account: '3109998888' }, { method_text: methodText });
  assert.equal(r.check.status, 'review');
  assert.ok(r.check.reasons.some((x) => x.includes('termina en 8888')));
});

test('not a receipt is flagged', async () => {
  const r = await check({ is_payment_receipt: false });
  assert.equal(r.check.status, 'review');
});

test('AI failure is "unverified", but a reused reference still turns it into "review"', async () => {
  const r = await check(undefined, {});
  assert.equal(r.check.status, 'unverified');
  const r2 = await check(undefined, { reused_reference: [{ id: '77777777-0000-4000-8000-000000000000', status: 'approved' }] });
  assert.equal(r2.check.status, 'review');
});

test('history query failure (error item) never breaks the verdict', async () => {
  const r = await check(good, { error: 'connection refused' });
  assert.equal(r.check.status, 'match');
});

test('seller email escapes text read from the image and asks to confirm in the bank', async () => {
  const r = await check({ ...good, bank: '<img src=x onerror=alert(1)>' });
  const email = await run(notify, 'Build email', {
    ...r.returned, seller_email: 's@example.com', seller_name: 'Tienda', buyer_name: 'Ana <b>', items: [{ name: 'Sticker', quantity: 1, unit_price: 50000 }],
  });
  assert.ok(!email.json.html.includes('<img'));
  assert.ok(email.json.html.includes('&lt;img'));
  assert.ok(email.json.html.includes('confirma que el dinero ya entró'));
  assert.match(email.json.subject, /^✅ Datos OK/);
});
