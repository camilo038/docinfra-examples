# DocInfra Postman collection

| File | Contents |
| --- | --- |
| `DocInfra.postman_collection.json` | Collection v2.1 with every public `/v1` endpoint, grouped in folders |
| `DocInfra.postman_environment.json` | Environment `DocInfra` with `base_url` and an empty `DOCINFRA_API_KEY` of type secret |

No API key is stored in either file.

## Import

1. Create a free account at https://app.apidocinfra.com and create an API key in the dashboard.
2. In Postman, click **Import** and drop both JSON files.
3. Pick the **DocInfra** environment in the top right selector and paste your key into `DOCINFRA_API_KEY` (current value). Keep the initial value empty so the key is never synced or shared.
4. Send **Text Rewrite > Rewrite text**. It should return `200`.
5. For files, open **Document Conversion > Convert DOCX to PDF**, choose a file in the `file` field of the body, send it (`202`), then send **Jobs > Get job** until `status` is `completed`.

What the collection does for you:

- Auth: the collection uses Bearer auth with `{{DOCINFRA_API_KEY}}`, so every request sends `Authorization: Bearer <key>`.
- Idempotency: a collection pre-request script adds a random `Idempotency-Key` to `POST /v1/documents/convert` and `POST /v1/documents/rewrite`, where the API requires it. It leaves `POST /v1/text/rewrite` and `POST /v1/webhooks` alone because the key is optional there; add it by hand if you want to test replays. A header you set yourself is never overwritten.
- Variables: a collection test script stores `job_id` and `document_id` from any `202` response and `webhook_id` from `POST /v1/webhooks`, so the Jobs, Documents and Webhooks requests work without copying ids.
- `base_url` exists both as a collection variable and in the environment. The environment value wins while it is selected.

The `download_url` returned by a completed job points at storage, not at the API. Open it with a plain GET and no headers; Postman sends the collection auth only to requests inside the collection.

## Publishing to a public Postman workspace

POSTMAN_PUBLICATION=HUMAN_ACTION_REQUIRED

This needs a person with a Postman account for DocInfra. Steps:

1. Sign in to Postman with the team account (not a personal one) and create a workspace named `DocInfra`, visibility **Public**. Postman asks for a public profile handle for the team first.
2. Import `DocInfra.postman_collection.json` and `DocInfra.postman_environment.json` into that workspace.
3. Before publishing, open the environment and confirm that `DOCINFRA_API_KEY` has an empty initial value and an empty current value. Check the collection variables too: `job_id`, `document_id` and `webhook_id` should be empty.
4. In the workspace overview add a short summary and the links to https://apidocinfra.com and https://app.apidocinfra.com.
5. Optional: from the collection menu, enable **Run in Postman** and copy the button snippet for the docs site.
6. Record the public workspace URL where the site and docs can link to it.

After any change to `docs/api-v1.md`, update this collection first and re-import it into the public workspace (Postman keeps the same collection if you import over it with **Replace**).
