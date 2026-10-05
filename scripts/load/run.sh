#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
compose() { docker compose -f docker-compose.dev.yml --profile loadtest "$@"; }
scenario="${SCENARIO:-load}"
results=scripts/load/results
mkdir -p "$results"

compose up -d --wait postgres mailpit
compose exec -T postgres psql -U postgres -q -c "drop database if exists app_load with (force)" -c "create database app_load"
compose up -d --build --force-recreate --wait api-load
compose exec -T api-load /app/seed

api=$(compose ps -q api-load)
database=$(compose ps -q postgres)
echo "time,container,cpu_percent,memory" > "$results/${scenario}_container_stats.csv"
(
  while docker inspect "$api" >/dev/null 2>&1; do
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" "$api" "$database" \
      | sed "s/^/$(date +%H:%M:%S),/" >> "$results/${scenario}_container_stats.csv" || true
    sleep 1
  done
) &
sampler=$!

compose run --rm --service-ports \
  -e SMOKE="${SMOKE:-0}" \
  -e K6_WEB_DASHBOARD_EXPORT="/scripts/results/${scenario}_report.html" \
  k6 run "/scripts/${scenario}.js" || status=$?
kill "$sampler" 2>/dev/null || true
echo "restarts: $(docker inspect -f '{{.RestartCount}}' "$api"), oom_killed: $(docker inspect -f '{{.State.OOMKilled}}' "$api")" | tee "$results/${scenario}_container_health.txt"
exit "${status:-0}"
