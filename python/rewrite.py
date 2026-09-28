"""DocInfra Text Rewrite with the standard library only.

Run: DOCINFRA_API_KEY=doc_live_... python rewrite.py
"""
import json
import os
import sys
import urllib.error
import urllib.request

api_key = os.environ.get("DOCINFRA_API_KEY")
if not api_key:
    sys.exit("Set DOCINFRA_API_KEY first.")
base_url = os.environ.get("DOCINFRA_BASE_URL", "https://api.apidocinfra.com")

text = (
    "It is important to note that Northwind Analytics closed Q3 with revenue of $2.4 million, "
    "up 18.5% from Q2. The board will review these results on October 15, 2026. "
    "The full report is available at https://example.com/reports/q3-2026 for all stakeholders."
)

payload = {
    "text": text,
    "mode": "professional",
    "intensity": "medium",
    "language": "auto",
    "protected_terms": ["Northwind Analytics"],
}

request = urllib.request.Request(
    f"{base_url}/v1/text/rewrite",
    data=json.dumps(payload).encode("utf-8"),
    method="POST",
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    },
)

try:
    with urllib.request.urlopen(request, timeout=150) as response:
        body = json.load(response)
except urllib.error.HTTPError as error:
    problem = json.load(error)
    print(f"{error.code} {problem.get('code')}: {problem.get('detail') or problem.get('title')}", file=sys.stderr)
    print(f"request_id: {problem.get('request_id')}", file=sys.stderr)
    sys.exit(1)

print(body["text"])
print(f"\nrewrite_id: {body['rewrite_id']}")
print(f"language: {body['language']}, changed: {body['metrics']['changed_percent']}%")
