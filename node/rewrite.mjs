// Node 20+, no dependencies: DOCINFRA_API_KEY=doc_live_... node rewrite.mjs

const apiKey = process.env.DOCINFRA_API_KEY;
if (!apiKey) {
  console.error('Set DOCINFRA_API_KEY first.');
  process.exit(1);
}
const baseUrl = process.env.DOCINFRA_BASE_URL ?? 'https://api.apidocinfra.com';

const text =
  'It is important to note that Northwind Analytics closed Q3 with revenue of $2.4 million, ' +
  'up 18.5% from Q2. The board will review these results on October 15, 2026. ' +
  'The full report is available at https://example.com/reports/q3-2026 for all stakeholders.';

const response = await fetch(`${baseUrl}/v1/text/rewrite`, {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    text,
    mode: 'professional',
    intensity: 'medium',
    language: 'auto',
    protected_terms: ['Northwind Analytics'],
  }),
});

const body = await response.json();
if (!response.ok) {
  console.error(`${response.status} ${body.code}: ${body.detail ?? body.title}`);
  console.error(`request_id: ${body.request_id ?? response.headers.get('x-request-id')}`);
  process.exit(1);
}

console.log(body.text);
console.log(`\nrewrite_id: ${body.rewrite_id}`);
console.log(`language: ${body.language}, changed: ${body.metrics.changed_percent}%`);
