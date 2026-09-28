# DocInfra API examples

Minimal clients for the DocInfra API v1. Each one reads the API key from `DOCINFRA_API_KEY` and never stores it. `DOCINFRA_BASE_URL` overrides the default `https://api.apidocinfra.com`.

| File | Runtime | What it does |
| --- | --- | --- |
| `curl.sh` | bash, curl 7.76+, jq for `convert` | `rewrite`: text rewrite. `convert <file>`: DOCX or HTML to PDF with job polling and download |
| `node/rewrite.mjs` | Node 20+, no dependencies | Text rewrite with `fetch` |
| `python/rewrite.py` | Python 3.8+, standard library only | Text rewrite with `urllib` |
| `java/Rewrite.java` | Java 17+, no dependencies | Text rewrite with `java.net.http`, runnable as a single file |

## Setup

1. Create a free account at https://app.apidocinfra.com and create an API key in the dashboard.
2. Export it in your shell. Do not commit it or paste it into the files.

```bash
export DOCINFRA_API_KEY=doc_live_...
```

## Run

```bash
./curl.sh rewrite
./curl.sh convert report.docx
node node/rewrite.mjs
python python/rewrite.py
java java/Rewrite.java
```

The sample text contains a company name, money, a percentage, a date and a URL:

> It is important to note that Northwind Analytics closed Q3 with revenue of $2.4 million, up 18.5% from Q2. The board will review these results on October 15, 2026. The full report is available at https://example.com/reports/q3-2026 for all stakeholders.

Numbers, dates, URLs, emails, citations and code are protected by default (`preserve`, all `true`), and `Northwind Analytics` is passed in `protected_terms`. They come back exactly as sent. If the API cannot guarantee that, it answers `422 PRESERVATION_FAILED` and returns no text.

## The async pattern (convert and document rewrite)

`POST /v1/documents/convert` and `POST /v1/documents/rewrite` never process the file inside the request:

1. `POST` the file as `multipart/form-data` with an `Idempotency-Key` header (required on both). The answer is `202` with `job_id` and `document_id`.
2. `GET /v1/jobs/{job_id}` until `status` is `completed`, `failed` or `rejected` (`queued` and `processing` mean keep waiting).
3. On `completed`, download `download_url` with a plain GET and no headers. It points at storage, expires after 5 minutes, and each job request returns a new one.

```bash
curl -X POST https://api.apidocinfra.com/v1/documents/convert \
  -H "Authorization: Bearer $DOCINFRA_API_KEY" \
  -H "Idempotency-Key: convert-report-001" \
  -F "file=@report.docx" \
  -F "output_format=pdf"

curl https://api.apidocinfra.com/v1/jobs/job_01M37FVAZAE46RTZST77WRFC7X \
  -H "Authorization: Bearer $DOCINFRA_API_KEY"

curl -o report.pdf "<download_url from the completed job>"
```

Retrying with the same `Idempotency-Key` and the same file returns the same job with `Idempotent-Replayed: true`. The same key with a different file returns `409 IDEMPOTENCY_CONFLICT`.

## Errors

Errors are `application/problem+json` with a stable `code` and a `request_id`. Branch on `code` (for example `INVALID_API_KEY`, `RATE_LIMIT_EXCEEDED`, `PRESERVATION_FAILED`), not on `title` or `detail`. Include `request_id` when you contact support.

## Publishing as a public repository

GITHUB_EXAMPLES=HUMAN_ACTION_REQUIRED

Publishing these files as a public GitHub repository needs a decision first: which organization or account owns it, the repository name, and the license. Until then they live only in this folder.
