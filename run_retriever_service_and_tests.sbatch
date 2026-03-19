#!/usr/bin/env bash
#SBATCH --job-name=flashrag_retriever_test
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

set -euo pipefail

# User-overridable parameters
PORT="${PORT:-3001}"
NUM_RETRIEVER="${NUM_RETRIEVER:-1}"
CONDA_ENV="${CONDA_ENV:-flash_rag311}"
RETRIEVER_CONFIG="${RETRIEVER_CONFIG:-retriever_config.yaml}"

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(pwd)}"
cd "${PROJECT_DIR}"

LOG_DIR="${LOG_DIR:-${PROJECT_DIR}/logs}"
mkdir -p "${LOG_DIR}"
JOB_ID="${SLURM_JOB_ID:-local}"
RESULT_LOG_FILE="${RESULT_LOG_FILE:-${LOG_DIR}/sbatch_test_results.log}"
TEST_LOG_FILE="${TEST_LOG_FILE:-${LOG_DIR}/api_smoke_test_${JOB_ID}.log}"

finalize() {
  local exit_code=$?
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local result="FAIL"
  if [[ "${exit_code}" -eq 0 ]]; then
    result="PASS"
  fi

  printf "%s job_id=%s result=%s port=%s retrievers=%s config=%s test_log=%s\n" \
    "${timestamp}" "${JOB_ID}" "${result}" "${PORT}" "${NUM_RETRIEVER}" "${RETRIEVER_CONFIG}" "${TEST_LOG_FILE}" >> "${RESULT_LOG_FILE}"

  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "[INFO] Stopping retriever server (pid=${SERVER_PID})"
    kill "${SERVER_PID}" || true
    wait "${SERVER_PID}" || true
  fi
}
trap finalize EXIT

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV}"

echo "[INFO] Starting retriever service on port ${PORT}"
bash run_retriever_serving.sh "${PORT}" "${NUM_RETRIEVER}" "${RETRIEVER_CONFIG}" &
SERVER_PID=$!

echo "[INFO] Waiting for service health check"
for i in $(seq 1 120); do
  if curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    echo "[INFO] Service is healthy"
    break
  fi
  sleep 2
  if [[ "${i}" == "120" ]]; then
    echo "[ERROR] Service failed to become healthy in time"
    exit 1
  fi
done

echo "[INFO] Running API smoke tests"
bash run_retriever_api_tests.sh "http://127.0.0.1:${PORT}" 2>&1 | tee "${TEST_LOG_FILE}"

echo "[INFO] Slurm job completed successfully"
