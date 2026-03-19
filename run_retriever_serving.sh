#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-3001}"
NUM_RETRIEVER="${2:-1}"

python retriever_serving.py \
  --config retriever_config.yaml \
  --num_retriever "${NUM_RETRIEVER}" \
  --port "${PORT}"
