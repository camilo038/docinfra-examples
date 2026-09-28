#!/usr/bin/env bash
# DocInfra API v1 with curl.
#   export DOCINFRA_API_KEY=doc_live_...
#   ./curl.sh rewrite
#   ./curl.sh convert path/to/file.docx
# The convert flow needs jq.
set -euo pipefail

: "${DOCINFRA_API_KEY:?Set DOCINFRA_API_KEY first}"
BASE_URL="${DOCINFRA_BASE_URL:-https://api.apidocinfra.com}"

rewrite() {
  curl -sS "$BASE_URL/v1/text/rewrite" \
    -H "Authorization: Bearer $DOCINFRA_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "text": "It is important to note that Northwind Analytics closed Q3 with revenue of $2.4 million, up 18.5% from Q2. The board will review these results on October 15, 2026. The full report is available at https://example.com/reports/q3-2026 for all stakeholders.",
      "mode": "professional",
      "intensity": "medium",
      "language": "auto",
      "preserve": { "numbers": true, "urls": true, "emails": true, "citations": true, "code": true },
      "protected_terms": ["Northwind Analytics"]
    }'
  echo
}

convert() {
  local file="${1:?Usage: ./curl.sh convert file.docx|file.html}"
  local key="curl-$(date +%s)-$RANDOM"

  # 202 Accepted with job_id and document_id. Idempotency-Key is required.
  local submit
  submit=$(curl -sS --fail-with-body "$BASE_URL/v1/documents/convert" \
    -H "Authorization: Bearer $DOCINFRA_API_KEY" \
    -H "Idempotency-Key: $key" \
    -F "file=@$file" \
    -F "output_format=pdf")
  echo "$submit"
  local job_id
  job_id=$(echo "$submit" | jq -r '.job_id')

  local job status
  for _ in $(seq 1 60); do
    job=$(curl -sS --fail-with-body "$BASE_URL/v1/jobs/$job_id" \
      -H "Authorization: Bearer $DOCINFRA_API_KEY")
    status=$(echo "$job" | jq -r '.status')
    echo "status: $status"
    case "$status" in
      completed)
        # download_url points at storage: plain GET, no Authorization header, valid 5 minutes.
        curl -sS --fail -o "${file%.*}.pdf" "$(echo "$job" | jq -r '.download_url')"
        echo "saved ${file%.*}.pdf"
        return 0
        ;;
      failed|rejected)
        echo "$job" | jq '.error'
        return 1
        ;;
    esac
    sleep 2
  done
  echo "job $job_id still $status after 2 minutes" >&2
  return 1
}

case "${1:-rewrite}" in
  rewrite) rewrite ;;
  convert) shift; convert "$@" ;;
  *) echo "Usage: ./curl.sh rewrite | ./curl.sh convert file.docx" >&2; exit 2 ;;
esac
