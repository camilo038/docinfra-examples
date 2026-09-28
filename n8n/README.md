# DocInfra workflows for n8n

Two workflows you can import into n8n (self-hosted or n8n Cloud):

| File | What it does |
| --- | --- |
| `ai-generation-to-docinfra-rewrite.json` | Takes an AI-generated draft and rewrites it with `POST /v1/text/rewrite`, keeping figures, dates and URLs exact, then hands the text to the next app |
| `docx-to-pdf.json` | Uploads a DOCX to `POST /v1/documents/convert`, polls `GET /v1/jobs/{job_id}` until the job ends, and downloads the PDF |

Neither file contains an API key. Both use an n8n credential named `DocInfra API`.

## Import

1. Create a free account at https://app.apidocinfra.com and create an API key in the dashboard.
2. In n8n, open **Credentials > Add credential > Header Auth** and fill it in:
   - Name: `DocInfra API`
   - Header name: `Authorization`
   - Header value: `Bearer doc_live_...` (your key, with the `Bearer ` prefix)
3. Open **Workflows > Add workflow**, then the menu at the top right, **Import from File**, and pick one of the JSON files.
4. Open each HTTP Request node that calls DocInfra and select the `DocInfra API` credential. The files carry a placeholder credential id, so n8n asks you to pick the real one on first open.
5. Click **Test workflow**.

The base URL lives in a Set node (`AI-generated draft` or `Config`) as `base_url`, set to `https://api.apidocinfra.com`.

## Tutorial 1: clean up AI-generated text before it reaches your CMS

Many teams generate first drafts with a language model: product descriptions, newsletters, support replies. The drafts are usable, but they tend to read the same way. "It is important to note that", "In today's fast-paced world", three-item lists everywhere. Asking the same model to "make it sound more natural" often works, until it silently turns 23.5% into "almost a quarter" or drops the link.

The first workflow puts DocInfra Text Rewrite between the generator and wherever the text goes next.

**1. Trigger.** The sample uses a Manual Trigger. In production, replace it with whatever produces your drafts: a schedule, a webhook from your app, or the output of the LLM node that writes the draft.

**2. The draft.** The `AI-generated draft` Set node holds a sample paragraph:

> In today's fast-paced world, it is important to note that our Q3 campaign reached 48,200 visitors, a 23.5% increase over Q2. Moreover, the new pricing page will go live on November 3, 2026. You can read the full announcement at https://example.com/blog/q3-results and share it with your team.

It has a figure, a percentage, a date and a URL, which are exactly the parts a plain model call tends to change.

**3. The rewrite.** The `DocInfra text rewrite` HTTP Request node sends:

```json
{
  "text": "<the draft>",
  "mode": "natural",
  "intensity": "medium",
  "language": "auto",
  "preserve": { "numbers": true, "urls": true, "emails": true, "citations": true, "code": true },
  "protected_terms": []
}
```

Numbers, dates, URLs, emails, citations, code and any `protected_terms` you list (brand names, product ids) are replaced by markers before the model sees the text, and each marker has to come back exactly once and in order. If that fails twice, the API answers `422 PRESERVATION_FAILED` and returns no text, so the workflow stops instead of publishing a changed figure. `mode` can be `natural`, `professional`, `conversational` or `concise`; `intensity` is `low`, `medium` or `high`. The output stays in the language of the input.

**4. Extract.** A successful call returns `200` with `text`, `rewrite_id`, `language`, `mode`, `intensity` and `metrics` (`input_words`, `output_words`, `changed_percent`). The `Extract rewritten text` node keeps `rewritten_text`, `rewrite_id` and `changed_percent`.

**5. Downstream.** Replace the `Downstream app (CMS, email, database)` placeholder with your destination: a WordPress or Ghost node, Gmail, a Postgres insert.

Notes:

- Text Rewrite is in beta and enabled per workspace. A workspace without it gets `403 REWRITE_NOT_ENABLED`.
- A request can carry up to 10,000 words or 80,000 characters.
- The text is not stored: neither the original nor the rewrite is kept in the database or written to logs. Add an `Idempotency-Key` header only if you need safe retries; with a key, the response is kept encrypted for one hour so a retry can replay it.
- The rewrite does not promise to evade AI detectors. It is measured on naturalness, preservation and meaning.

## Tutorial 2: convert Word documents to PDF

The second workflow shows the async pattern every DocInfra file operation follows: submit, get a job, poll, download.

**1. Input.** `Config` holds `base_url` and `file_path`, and `Read DOCX` (Read/Write Files from Disk) loads the file into the binary property `data`. On n8n Cloud, or when the file comes from somewhere else, swap `Read DOCX` for a Webhook node that receives an upload, a Google Drive download or an email attachment. What matters is that the DOCX ends up in a binary property called `data`, or that you change `Input Data Field Name` in the next node.

**2. Submit.** `Submit conversion` sends a `multipart/form-data` request to `POST /v1/documents/convert` with two fields: `file` (the binary) and `output_format` set to `pdf`. The endpoint requires an `Idempotency-Key` header; the workflow builds one from the execution id, so a retry of the same execution does not create a second job. The response is `202 Accepted`:

```json
{ "job_id": "job_...", "document_id": "doc_...", "status": "queued", "created_at": "..." }
```

HTML files work the same way: send an `.html` in `file`.

**3. Poll.** `Wait 5 seconds`, then `Get job status` calls `GET /v1/jobs/{job_id}`. The job moves through `queued`, `processing` and ends in `completed`, `failed` or `rejected`. `Job finished?` sends the item back to the wait while the status is still `queued` or `processing`. Conversions usually finish in a few seconds. If you want a hard stop, add a counter and an extra IF after a number of rounds.

**4. Download.** `Completed?` routes a `completed` job to `Download PDF`, which fetches `download_url` from the job response with a plain GET and no credential. That URL points at storage, not at the API, expires after 5 minutes, and a new one comes with each job request. Do not send your API key to it and do not store it for later. The PDF lands in the binary property `data`.

**5. Deliver.** Replace `Storage or email` with S3, Google Drive, Dropbox or an email node. A `failed` or `rejected` job goes to the other branch with `error.code` (for example `CONVERSION_FAILED` or `MALWARE_DETECTED`) and a fixed `error.message`.

Instead of polling you can register a webhook (`POST /v1/webhooks`) for `document.completed` and fetch the job when the event arrives. The event body never contains the download URL; call `GET /v1/jobs/{job_id}` to get a fresh one.

## Node types used

`n8n-nodes-base.manualTrigger` (v1), `n8n-nodes-base.set` (v3.4), `n8n-nodes-base.httpRequest` (v4.2), `n8n-nodes-base.wait` (v1.1), `n8n-nodes-base.if` (v2), `n8n-nodes-base.noOp` (v1) and `n8n-nodes-base.readWriteFile` (v1). They are available in n8n 1.x.
