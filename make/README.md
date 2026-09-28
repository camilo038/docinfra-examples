# DocInfra scenarios for Make

Make blueprints are awkward to write by hand and break between module versions, so this page describes the two scenarios module by module. Both use the built-in **HTTP > Make a request** module. The same flows exist as importable n8n workflows in `../n8n/`.

## Before you start

1. Create a free account at https://app.apidocinfra.com and create an API key in the dashboard.
2. Keep the key out of the scenario itself. Two options:
   - In the HTTP module, set **Authentication type** to **API Key** and create a keychain with key `Bearer doc_live_...`, placement **In the header**, parameter name `Authorization`.
   - Or, if your Make plan has custom variables, create one named `DOCINFRA_API_KEY` and add a header `Authorization` with value `Bearer {{DOCINFRA_API_KEY}}`.
3. Base URL for every request: `https://api.apidocinfra.com`.

Every DocInfra error is `application/problem+json` with a stable `code` field. Enable **Evaluate all states as errors** (on by default) so a 4xx or 5xx stops the run, and add an error handler route if you need one. Decide on `code`, not on `title` or `detail`.

## Scenario 1: AI-generated text to DocInfra Text Rewrite

Flow: trigger → JSON Create JSON → HTTP Make a request → downstream module.

**Trigger.** Any module that produces the draft: an LLM module, a **Webhooks > Custom webhook**, or **Tools > Set variable** for a test. Sample draft with the parts that must not change:

> In today's fast-paced world, it is important to note that our Q3 campaign reached 48,200 visitors, a 23.5% increase over Q2. Moreover, the new pricing page will go live on November 3, 2026. You can read the full announcement at https://example.com/blog/q3-results and share it with your team.

**HTTP > Make a request.**

| Field | Value |
| --- | --- |
| URL | `https://api.apidocinfra.com/v1/text/rewrite` |
| Method | `POST` |
| Headers | Authorization, through the keychain or the custom variable above |
| Body content type | `application/json` |
| Body input method | JSON string |
| Body content | the JSON string from a **JSON > Create JSON** module placed before this one |
| Parse response | Yes |

The body has this shape:

```json
{
  "text": "<the draft>",
  "mode": "natural",
  "intensity": "medium",
  "language": "auto",
  "preserve": { "numbers": true, "urls": true, "emails": true, "citations": true, "code": true },
  "protected_terms": ["Northwind Analytics"]
}
```

Build it with **JSON > Create JSON** (a data structure with `text`, `mode`, `intensity`, `language`, `preserve` as a collection of five booleans and `protected_terms` as an array of text) and map the draft into `text`. Pasting the draft between quotes in a raw body breaks as soon as the text contains a quote or a line break.

`Idempotency-Key` is optional on this endpoint. Add the header only if you want safe retries: the same key with the same body within one hour returns the same response with `Idempotent-Replayed: true`, and the same key with another body returns `409 IDEMPOTENCY_CONFLICT`.

Expected response `200`:

```json
{
  "rewrite_id": "rwr_...",
  "text": "...",
  "language": "en",
  "mode": "natural",
  "intensity": "medium",
  "metrics": { "input_words": 47, "output_words": 38, "changed_percent": 35.2 }
}
```

**Last module: downstream.** Map `data.text` from the HTTP module into your CMS, email or database module. `data.rewrite_id` and `data.metrics.changed_percent` are useful to log.

If the API cannot keep every number, date, URL, email, citation, code fragment and protected term exactly, it answers `422 PRESERVATION_FAILED` with no text. Let that stop the run rather than publishing the original by accident. Text Rewrite is in beta and enabled per workspace; otherwise the API answers `403 REWRITE_NOT_ENABLED`.

## Scenario 2: DOCX to PDF

Flow: trigger with a file → HTTP convert → Repeater → Sleep → HTTP job status → Array aggregator → HTTP job status → Router → HTTP download → storage or email.

**Module 1: trigger with a file.** For example **Google Drive > Watch files** followed by **Google Drive > Download a file**, **Email > Watch emails** with an attachment iterator, or **Webhooks > Custom webhook** receiving an upload. You need the file data and its name ending in `.docx` (or `.html`).

**Module 2: HTTP > Make a request (submit).**

| Field | Value |
| --- | --- |
| URL | `https://api.apidocinfra.com/v1/documents/convert` |
| Method | `POST` |
| Headers | Authorization as above, plus `Idempotency-Key` = `make-{{scenario.executionId}}-{{1.id}}` (any value of 1 to 255 visible ASCII characters that is unique per file) |
| Body content type | `multipart/form-data` |
| Fields | `file`: field type **File**, file name mapped from module 1 (must end in `.docx` or `.html`), data mapped from module 1. `output_format`: field type **Text**, value `pdf` |
| Parse response | Yes |

`Idempotency-Key` is required here; without it the API answers `400 MISSING_IDEMPOTENCY_KEY`. Reusing the key for the same file returns the same job; reusing it for another file returns `409 IDEMPOTENCY_CONFLICT`. Expected response `202`:

```json
{ "job_id": "job_...", "document_id": "doc_...", "status": "queued", "created_at": "..." }
```

**Modules 3 to 5: bounded wait.** Make has no "loop until" module, so the wait is a fixed number of rounds:

- **Flow Control > Repeater**: initial value 1, repeats 12.
- **Tools > Sleep**: delay 5 seconds.
- **HTTP > Make a request**: `GET https://api.apidocinfra.com/v1/jobs/{{2.data.job_id}}`, Authorization header, Parse response Yes.

This always polls 12 times over about a minute, which costs 12 reads (the read limit is 60 per 10 seconds per key). Conversions usually finish in a few seconds, so the later rounds only confirm the final state.

**Module 6: Flow Control > Array aggregator**, source module the Repeater. This closes the loop so the next modules run once.

**Module 7: HTTP > Make a request (final status).** Same as module 5: `GET https://api.apidocinfra.com/v1/jobs/{{2.data.job_id}}`. This returns a fresh `download_url`, which matters because each URL expires 5 minutes after it is issued.

**Module 8: Router** with three routes, each with a filter on `7.data.status`:

| Route filter | Next module |
| --- | --- |
| `status` equal to `completed` | Module 9 |
| `status` equal to `failed` or `rejected` | Notify or log `7.data.error.code` and `7.data.error.message` |
| `status` equal to `queued` or `processing` | Still running after a minute: log it and retry later, or raise the repeat count |

**Module 9: HTTP > Get a file** (or Make a request with **Parse response** off).

| Field | Value |
| --- | --- |
| URL | `{{7.data.download_url}}` |
| Method | `GET` |
| Headers | none. Do not send the Authorization header: this URL points at storage, not at the API |

**Module 10: storage or email.** Map the file data from module 9 and a file name such as `{{replace(1.name; ".docx"; ".pdf")}}` into Google Drive, Dropbox, S3 or an email attachment.

### Alternative: webhook instead of polling

Register an endpoint once with `POST /v1/webhooks` and the body `{"url": "<your Make custom webhook URL>", "events": ["document.completed", "document.failed", "document.rejected"]}`. The `201` response contains `secret` only once; store it to verify the `X-DocInfra-Signature` header. Then split the flow in two scenarios:

- Scenario A: trigger → HTTP submit (module 2 above). Done.
- Scenario B: **Webhooks > Custom webhook** → HTTP `GET https://api.apidocinfra.com/v1/jobs/{{1.data.job_id}}` → filter `status` equal to `completed` → HTTP get file from `download_url` → storage or email.

The event body carries `data.document_id`, `data.job_id` and `data.status`, never the download URL, so scenario B always asks the API for a fresh one.

## Document Rewrite

`POST /v1/documents/rewrite` works exactly like scenario 2 with a different URL and fields. Only `.docx` is accepted. Multipart fields: `file` (File), and optionally `mode`, `intensity`, `language` (Text) and `protected_terms` (Text, comma separated). `Idempotency-Key` is required. The completed job has `"type": "rewrite"` and its `download_url` returns a DOCX. Beta, enabled per workspace.
