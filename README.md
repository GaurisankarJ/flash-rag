# FlashRAG Standalone Serving HI
 
This folder is a self-contained setup for FlashRAG retriever serving.

It includes:

- Local FlashRAG code under `./flashrag/`
- Local retrieval model under `./models/e5-base-v2/`
- Both corpora under `./corpus/`
  - `wiki18_100w.jsonl` (full)
  - `wiki18_100w_mini.jsonl` (mini)
- FAISS mini index under `./indexes/wiki18_100w_mini_e5_flat_inner.index`
- Serving entrypoint `./retriever_serving.py`
- Serving config `./retriever_config.yaml`

## 1) Environment setup

Create and activate a dedicated conda env named `flash_rag311`:

```bash
conda create -n flash_rag311 python=3.11 -y
conda activate flash_rag311
```

### Install PyTorch

For macOS (Apple Silicon / CPU/MPS):

```bash
pip install torch torchvision torchaudio
```

For Linux with CUDA 12.4 (from original project setup):

```bash
pip install torch --index-url https://download.pytorch.org/whl/cu124
```

### Install FlashRAG serving dependencies

From this folder:

```bash
pip install -r requirements.txt
```

### Optional: enable FAISS GPU (Linux + NVIDIA)

`requirements.txt` installs `faiss-cpu` by default. If you want FAISS index search on GPU, install GPU FAISS in the conda environment:

```bash
conda install -c pytorch -c nvidia faiss-gpu=1.8.0
```

Then set `faiss_gpu: True` in your retriever config (`retriever_config.yaml` or `retriever_config_mini.yaml`).

## 2) Default serving config

`retriever_config.yaml` is preconfigured for mini serving:

- `retrieval_method: ./models/e5-base-v2/`
- `index_path: ./indexes/wiki18_100w_mini_e5_flat_inner.index`
- `corpus_path: ./corpus/wiki18_100w_mini.jsonl`

## 3) Start retriever server

From this folder:

```bash
bash run_retriever_serving.sh 3001 1 retriever_config_mini.yaml
```

Arguments:

- first arg: port (default `3001`)
- second arg: number of retriever instances (default `1`)
- third arg: config file path (default `retriever_config.yaml`)

Examples:

Mini wiki:

```bash
bash run_retriever_serving.sh 3001 1 retriever_config_mini.yaml
```

Full wiki:

```bash
bash run_retriever_serving.sh 3001 1 retriever_config.yaml
```

## 4) Test the server manually

Health:

```bash
curl -sS http://127.0.0.1:3001/health
```

Search:

```bash
curl -sS -X POST "http://127.0.0.1:3001/search" \
  -H "Content-Type: application/json" \
  -d '{"query":"What is the capital of France?","top_n":3,"return_score":false}'
```

## 5) Run API smoke tests (automated)

An automated API smoke-test suite is provided at:

- `./tests/retriever_api_smoke_test.py`

Helper runner:

- `./run_retriever_api_tests.sh`

Run against a local service:

```bash
bash run_retriever_api_tests.sh "http://127.0.0.1:3001"
```

The smoke test validates:

- `/health` status and retriever counts
- `/search` happy-path response shape
- `/batch_search` happy-path response shape
- `/search` empty-query validation (expects HTTP 400)

## 6) Run retriever + tests with Slurm (sbatch)

Use the provided Slurm batch file:

- `./run_retriever_service_and_tests.sbatch`

It does all of the following in one job:

1. Activates conda env (default `flash_rag311`)
2. Verifies CUDA GPU is available (default `REQUIRE_GPU=1`)
3. Creates a runtime config and forces `faiss_gpu: True`
4. Starts retriever service (`run_retriever_serving.sh`)
5. Waits for `/health` readiness
6. Runs the API smoke tests
7. Shuts down the service and exits with job status

Submit:

```bash
sbatch run_retriever_service_and_tests.sbatch
```

Optional overrides at submit time:

```bash
sbatch --export=ALL,CONDA_ENV=flash_rag311,PORT=3001,NUM_RETRIEVER=1 run_retriever_service_and_tests.sbatch
```

GPU-related overrides:

```bash
# Select a specific GPU and keep strict GPU requirement (default behavior)
sbatch --export=ALL,CONDA_ENV=flash_rag311,PORT=3001,NUM_RETRIEVER=1,RETRIEVER_CONFIG=retriever_config_mini.yaml,GPU_ID=0,REQUIRE_GPU=1 run_retriever_service_and_tests.sbatch
```

Check output logs:

```bash
tail -f slurm-<job_id>.out
tail -f slurm-<job_id>.err
```

## 7) Build index for mini or full corpus (optional)

If you need to rebuild indexes:

```bash
python -m flashrag.retriever.index_builder \
  --retrieval_method e5-base-v2 \
  --model_path ./models/e5-base-v2 \
  --corpus_path ./corpus/wiki18_100w_mini.jsonl \
  --save_dir ./indexes
```

For full wiki, switch `--corpus_path` to:

```text
./corpus/wiki18_100w.jsonl
```

Then update `retriever_config.yaml` to the matching corpus/index pair before starting the server.
