#!/usr/bin/env python3
import argparse
import json
import sys
import urllib.error
import urllib.request


def http_json(method, url, payload=None, timeout=30):
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url=url, method=method, data=data, headers=headers)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode("utf-8")
        return response.status, json.loads(body)


def assert_true(condition, message):
    if not condition:
        raise AssertionError(message)


def run_tests(base_url):
    print(f"[INFO] Running API smoke tests against {base_url}")

    # 1) Health endpoint
    status, health = http_json("GET", f"{base_url}/health")
    assert_true(status == 200, f"/health returned status {status}, expected 200")
    assert_true(health.get("status") == "healthy", "/health status field is not 'healthy'")
    retrievers = health.get("retrievers", {})
    assert_true("total" in retrievers and "available" in retrievers, "/health missing retriever counts")
    assert_true(retrievers["total"] >= 1, "/health reports no retrievers initialized")
    print("[PASS] /health")

    # 2) Search endpoint
    search_payload = {
        "query": "What is the capital of France?",
        "top_n": 3,
        "return_score": False,
    }
    status, search_results = http_json("POST", f"{base_url}/search", search_payload)
    assert_true(status == 200, f"/search returned status {status}, expected 200")
    assert_true(isinstance(search_results, list), "/search response should be a list")
    assert_true(len(search_results) > 0, "/search returned no results")
    first_result = search_results[0]
    assert_true(isinstance(first_result, dict), "/search first result should be an object")
    assert_true("id" in first_result and "contents" in first_result, "/search result missing id/contents")
    print("[PASS] /search")

    # 3) Batch search endpoint
    batch_payload = {
        "query": [
            "What is the capital of Germany?",
            "Who wrote Hamlet?",
        ],
        "top_n": 2,
        "return_score": False,
    }
    status, batch_results = http_json("POST", f"{base_url}/batch_search", batch_payload)
    assert_true(status == 200, f"/batch_search returned status {status}, expected 200")
    assert_true(isinstance(batch_results, list), "/batch_search response should be a list")
    assert_true(len(batch_results) == len(batch_payload["query"]), "/batch_search result length mismatch")
    assert_true(all(isinstance(item, list) for item in batch_results), "/batch_search items should be lists")
    assert_true(all(len(item) > 0 for item in batch_results), "/batch_search has an empty result set")
    print("[PASS] /batch_search")

    # 4) Validation behavior for empty query
    invalid_payload = {
        "query": "   ",
        "top_n": 1,
        "return_score": False,
    }
    try:
        http_json("POST", f"{base_url}/search", invalid_payload)
        raise AssertionError("/search accepted an empty query but should return HTTP 400")
    except urllib.error.HTTPError as err:
        assert_true(err.code == 400, f"/search empty query returned {err.code}, expected 400")
    print("[PASS] /search validation (empty query)")

    print("[INFO] All API smoke tests passed.")


def main():
    parser = argparse.ArgumentParser(description="Smoke tests for retriever service APIs.")
    parser.add_argument("--base-url", default="http://127.0.0.1:3001", help="Base URL for API service.")
    args = parser.parse_args()

    try:
        run_tests(args.base_url.rstrip("/"))
    except Exception as exc:  # noqa: BLE001
        print(f"[FAIL] {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
