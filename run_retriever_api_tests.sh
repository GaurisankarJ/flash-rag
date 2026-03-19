#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:3001}"

python tests/retriever_api_smoke_test.py --base-url "${BASE_URL}"
