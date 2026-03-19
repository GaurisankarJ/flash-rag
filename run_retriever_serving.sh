#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-3001}"
NUM_RETRIEVER="${2:-1}"
RETRIEVER_CONFIG="${3:-retriever_config.yaml}"

# Avoid OpenMP runtime crashes on some platforms/Python builds.
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export KMP_INIT_AT_FORK="${KMP_INIT_AT_FORK:-FALSE}"

python retriever_serving.py \
  --config "${RETRIEVER_CONFIG}" \
  --num_retriever "${NUM_RETRIEVER}" \
  --port "${PORT}"
