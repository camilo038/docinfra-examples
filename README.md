# DocInfra API Examples

Copy-paste examples for the [DocInfra API](https://apidocinfra.com/?utm_source=github&utm_medium=examples): rewrite AI-generated text so it reads naturally while numbers, dates, citations, URLs, code and protected terms come back exactly as sent. If they cannot be restored, the call fails instead of returning a changed text.

## Humanize/rewrite text in under 5 minutes

1. [Create a free DocInfra account](https://app.apidocinfra.com/?utm_source=github&utm_medium=examples) (no card) and create an API key in the dashboard.
2. Export the key:

   ```bash
   export DOCINFRA_API_KEY=your_key_here
   ```

3. Run one call:

   ```bash
   curl -sS https://api.apidocinfra.com/v1/text/rewrite \
     -H "Authorization: Bearer $DOCINFRA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"text":"It is important to note that revenue grew 18.5% to $2.4 million in Q3 2026, as described at https://example.com/q3.","mode":"natural","intensity":"medium"}'
   ```

The same call in other languages: [`node/rewrite.mjs`](node/rewrite.mjs), [`python/rewrite.py`](python/rewrite.py), [`java/Rewrite.java`](java/Rewrite.java), [`curl.sh`](curl.sh). Details in [CLIENTS.md](CLIENTS.md).

## Document Rewrite (beta)

Send a DOCX, get a rewritten DOCX back with the same structure, tables and protected values. Async: the API answers `202` with a job; poll it or use a webhook. See the Postman collection and [CLIENTS.md](CLIENTS.md).

## DOCX/HTML to PDF

`POST /v1/documents/convert` with a DOCX or HTML file, then poll `GET /v1/jobs/{job_id}` until `completed` and download the PDF from `download_url`:

```bash
./curl.sh convert report.docx
```

## n8n

Two importable workflows in [`n8n/`](n8n/): AI generation, DocInfra Rewrite, downstream app; and DOCX, DocInfra conversion, job polling, PDF to storage or email. They use the standard HTTP Request node, no custom node needed.

## Make

Equivalent Make scenarios with the HTTP module, step by step, in [`make/README.md`](make/README.md).

## Postman

Import [`postman/DocInfra.postman_collection.json`](postman/DocInfra.postman_collection.json) and the environment, set `DOCINFRA_API_KEY`, and send "Rewrite text".

## Links

- [Try the free Humanizer](https://apidocinfra.com/humanize/?utm_source=github&utm_medium=examples) before integrating.
- [API documentation](https://apidocinfra.com/ai-humanizer-api/?utm_source=github&utm_medium=examples)
- [Create a free account](https://app.apidocinfra.com/?utm_source=github&utm_medium=examples)

Never commit your API key. `.env` is ignored by this repository; copy `.env.example` if you want a local file.
