#!/usr/bin/env python3
"""Binary-searches the highest sustainable request rate for the api-load container.

Requires the loadtest compose profile (api-load, k6). Results land in scripts/load/results.

A probe passes when, over its 60 s measurement window, fewer than 1% of requests
fail, p95 latency stays under 500 ms and k6 drops under 1% of scheduled iterations.
Usage: python3 scripts/load/find_breaking_point.py [first_probe_rate]
"""
import json
import os
import subprocess
import sys
import threading
import time
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RESULTS = os.path.join(ROOT, "scripts", "load", "results")
COMPOSE = ["docker", "compose", "-f", "docker-compose.dev.yml", "--profile", "loadtest"]
MEASURE_SECONDS = 60


def sh(args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, **kwargs)


def container_id(service):
    return sh(COMPOSE + ["ps", "-q", service], capture_output=True, text=True).stdout.strip()


def reset_environment():
    sh(COMPOSE + ["up", "-d", "--wait", "postgres", "mailpit"], capture_output=True)
    sh(COMPOSE + ["exec", "-T", "postgres", "psql", "-U", "postgres", "-q", "-c", "drop database if exists app_load with (force)", "-c", "create database app_load"], capture_output=True)
    sh(COMPOSE + ["up", "-d", "--build", "--force-recreate", "--wait", "api-load"], capture_output=True)
    sh(COMPOSE + ["exec", "-T", "api-load", "/app/seed"], capture_output=True)


def k6(mode, rate=0):
    args = COMPOSE + ["run", "--rm", "--service-ports", "-e", f"MODE={mode}", "-e", f"RATE={rate}"]
    if mode == "prepare":
        args += ["-e", "K6_WEB_DASHBOARD=false"]
    else:
        args += ["-e", f"K6_WEB_DASHBOARD_EXPORT=/scripts/results/probe_{rate}_report.html"]
    args += ["k6", "run", "--quiet", "/scripts/breaking_point.js"]
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True)


def parse_mib(text):
    value = text.split("/")[0].strip()
    number = float("".join(ch for ch in value if ch.isdigit() or ch == "."))
    if value.endswith("GiB"):
        return number * 1024
    if value.endswith("KiB"):
        return number / 1024
    return number


class Sampler(threading.Thread):
    def __init__(self, api, database):
        super().__init__(daemon=True)
        self.api, self.database = api, database
        self.samples = []
        self.running = True

    def run(self):
        while self.running:
            output = subprocess.run(
                ["docker", "stats", "--no-stream", "--format", "{{.ID}},{{.CPUPerc}},{{.MemUsage}}", self.api, self.database],
                capture_output=True, text=True,
            ).stdout
            sample = {"t": time.time()}
            for line in output.strip().splitlines():
                identifier, cpu, memory = line.split(",", 2)
                key = "api" if self.api.startswith(identifier) else "pg"
                sample[f"{key}_cpu"] = float(cpu.rstrip("%"))
                sample[f"{key}_mem"] = parse_mib(memory)
            if "api_cpu" in sample:
                self.samples.append(sample)
            time.sleep(0.5)


def wait_healthy(timeout=120):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen("http://localhost:" + os.environ.get("API_LOAD_PORT", "4001") + "/health", timeout=2) as response:
                if response.status == 200:
                    return True
        except Exception:
            pass
        time.sleep(1)
    return False


def metric(metrics, name, field, default=0.0):
    return metrics.get(name, {}).get("values", {}).get(field, default)


def ensure_api_running():
    sh(COMPOSE + ["up", "-d", "--wait", "api-load"], capture_output=True)
    wait_healthy()


def probe(rate, api, database):
    ensure_api_running()
    api = container_id("api-load")
    sampler = Sampler(api, database)
    sampler.start()
    started = time.time()
    outcome = k6("probe", rate)
    finished = time.time()
    sampler.running = False
    sampler.join()
    with open(os.path.join(RESULTS, f"probe_{rate}.json")) as handle:
        metrics = json.load(handle)
    window = [s for s in sampler.samples if finished - MEASURE_SECONDS - 3 <= s["t"] <= finished - 3] or sampler.samples
    health = sh(["docker", "inspect", "-f", "{{.RestartCount}},{{.State.OOMKilled}},{{.State.Status}}", api], capture_output=True, text=True).stdout.strip()
    result = {
        "target_rate": rate,
        "achieved_rps": metric(metrics, "http_reqs{phase:measure}", "count") / MEASURE_SECONDS,
        "iterations_per_s": metric(metrics, "iterations{phase:measure}", "count") / MEASURE_SECONDS,
        "p50_ms": metric(metrics, "http_req_duration{phase:measure}", "med"),
        "p95_ms": metric(metrics, "http_req_duration{phase:measure}", "p(95)"),
        "p99_ms": metric(metrics, "http_req_duration{phase:measure}", "p(99)"),
        "error_rate": metric(metrics, "http_req_failed{phase:measure}", "rate"),
        "shed_rps": metric(metrics, "http_reqs{phase:measure,status:503}", "count") / MEASURE_SECONDS,
        "admitted_p95_ms": metric(metrics, "http_req_duration{phase:measure,expected_response:true}", "p(95)"),
        "admitted_p99_ms": metric(metrics, "http_req_duration{phase:measure,expected_response:true}", "p(99)"),
        "dropped": metric(metrics, "dropped_iterations{scenario:measure}", "count"),
        "api_cpu_avg": sum(s["api_cpu"] for s in window) / len(window),
        "api_cpu_max": max(s["api_cpu"] for s in window),
        "api_mem_max_mib": max(s["api_mem"] for s in window),
        "pg_cpu_avg": sum(s.get("pg_cpu", 0) for s in window) / len(window),
        "pg_cpu_max": max(s.get("pg_cpu", 0) for s in window),
        "pg_mem_max_mib": max(s.get("pg_mem", 0) for s in window),
        "container": health,
        "wall_seconds": round(finished - started),
        "k6_exit": outcome.returncode,
    }
    result["passed"] = (
        result["error_rate"] < 0.01
        and result["p95_ms"] < 500
        and result["dropped"] < 0.01 * rate * MEASURE_SECONDS
    )
    with open(os.path.join(RESULTS, f"probe_{rate}_samples.json"), "w") as handle:
        json.dump(sampler.samples, handle)
    return result


def describe(result):
    verdict = "PASS" if result["passed"] else "FAIL"
    return (
        f"{verdict} target={result['target_rate']}/s achieved={result['achieved_rps']:.0f} req/s "
        f"p50={result['p50_ms']:.0f}ms p95={result['p95_ms']:.0f}ms p99={result['p99_ms']:.0f}ms "
        f"errors={result['error_rate'] * 100:.2f}% shed={result['shed_rps']:.0f}/s "
        f"admitted p95={result['admitted_p95_ms']:.0f}ms p99={result['admitted_p99_ms']:.0f}ms dropped={result['dropped']:.0f} | "
        f"api cpu avg={result['api_cpu_avg']:.0f}% max={result['api_cpu_max']:.0f}% mem={result['api_mem_max_mib']:.0f}MiB | "
        f"pg cpu avg={result['pg_cpu_avg']:.0f}% max={result['pg_cpu_max']:.0f}% | container={result['container']}"
    )


def verify(rates):
    os.makedirs(RESULTS, exist_ok=True)
    ensure_api_running()
    database = container_id("postgres")
    results = []
    for rate in rates:
        result = probe(rate, container_id("api-load"), database)
        results.append(result)
        print(describe(result), flush=True)
        time.sleep(10)
    with open(os.path.join(RESULTS, "overload_verification.json"), "w") as handle:
        json.dump(results, handle, indent=2)
    print("VERIFICATION DONE", flush=True)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "verify":
        verify([int(rate) for rate in sys.argv[2:]])
        return
    first = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    known_failing = int(sys.argv[2]) if len(sys.argv) > 2 else None
    os.makedirs(RESULTS, exist_ok=True)
    if os.environ.get("REUSE") == "1" and os.path.exists(os.path.join(RESULTS, "breaking_point_state.json")):
        print("reusing prepared app_load data", flush=True)
        ensure_api_running()
    else:
        print("resetting app_load and api-load", flush=True)
        reset_environment()
        print("preparing riders, drivers and bookings", flush=True)
        prepared = k6("prepare")
        print("\n".join(line for line in prepared.stdout.splitlines() + prepared.stderr.splitlines() if "prepare:" in line), flush=True)
    api, database = container_id("api-load"), container_id("postgres")

    results = []
    passing, failing = 0, known_failing
    rate = first
    while True:
        result = probe(rate, api, database)
        results.append(result)
        print(describe(result), flush=True)
        if result["passed"]:
            passing = rate
            rate = rate * 2 if failing is None else (passing + failing) // 2
        else:
            failing = rate
            rate = (passing + failing) // 2
        if failing is not None and failing - passing <= max(50, passing * 0.1):
            break
        if rate <= 0:
            break
        time.sleep(10)

    with open(os.path.join(RESULTS, "breaking_point.json"), "w") as handle:
        json.dump(results, handle, indent=2)
    print(f"BREAKING POINT: sustains {passing}/s, breaks at {failing}/s", flush=True)


if __name__ == "__main__":
    main()
