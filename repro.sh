#!/usr/bin/env bash
set -Eeuo pipefail

# Reproduce parked-session replay corruption across an Eve upgrade.
# Requires Node 24+, Docker, curl, and a PostgreSQL container named eve-repro-pg
# exposing postgres://eve:eve@localhost:5432. Set AI_GATEWAY_API_KEY (or the
# provider key required by your Eve model) before running.

OLD_EVE="${OLD_EVE:-0.47.2}"
NEW_EVE="${NEW_EVE:-0.47.3}"
WORLD="${WORLD:-5.0.0-beta.35}"
PORT="${PORT:-4224}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/eve-pg-repro.XXXXXX")"
DB="eve_repro_${RANDOM}_$"
PID=""

cleanup() {
  set +e
  [[ -n "$PID" ]] && kill "$PID" 2>/dev/null && wait "$PID" 2>/dev/null
  docker exec eve-repro-pg psql -U eve -d postgres -c "DROP DATABASE IF EXISTS $DB" >/dev/null 2>&1
  echo "Logs and temporary files: $TMP"
}
trap cleanup EXIT
fail() { echo "ERROR: $*" >&2; [[ -f "$TMP/server.log" ]] && tail -80 "$TMP/server.log" >&2; exit 1; }
wait_health() { for _ in {1..60}; do curl -fsS "http://127.0.0.1:$PORT/eve/v1/health" >/dev/null 2>&1 && return; sleep 1; done; fail "Eve server did not become healthy"; }
stop_server() { [[ -z "$PID" ]] && return; kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; PID=""; }
start_server() { PORT="$PORT" ./node_modules/.bin/eve start >>"$TMP/server.log" 2>&1 & PID=$!; wait_health; }

command -v node >/dev/null || fail "node is required"
command -v npm >/dev/null || fail "npm is required"
command -v curl >/dev/null || fail "curl is required"
docker inspect eve-repro-pg >/dev/null 2>&1 || fail "Docker container eve-repro-pg is missing"
[[ -n "${AI_GATEWAY_API_KEY:-}${ANTHROPIC_API_KEY:-}" ]] || echo "Warning: no AI key detected; the model turn may fail."

cp -R "$ROOT/agent" "$ROOT/package.json" "$TMP/"
cd "$TMP"

echo "Testing Eve $OLD_EVE -> $NEW_EVE with world-postgres $WORLD"
EVE_OLD_TARBALL="$(npm view "eve@$OLD_EVE" dist.tarball)"
WORLD_TARBALL="$(npm view "@workflow/world-postgres@$WORLD" dist.tarball)"
npm install --no-audit --no-fund --save-exact "$EVE_OLD_TARBALL" "$WORLD_TARBALL" >/dev/null

docker exec eve-repro-pg psql -U eve -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE $DB" >/dev/null || fail "could not create database"
export WORKFLOW_POSTGRES_URL="postgres://eve:eve@127.0.0.1:5432/$DB"
npx --yes --package="$WORLD_TARBALL" bootstrap >/dev/null 2>&1 || fail "database bootstrap failed"
./node_modules/.bin/eve build >/dev/null || fail "old build failed"
start_server

created=$(curl -fsS -X POST "http://127.0.0.1:$PORT/eve/v1/session" -H 'content-type: application/json' -d '{"message":"Remember that my favorite city is Lyon."}') || fail "old session creation failed"
session=$(printf '%s' "$created" | sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p')
[[ -n "$session" ]] || fail "session ID missing from: $created"
sleep 8
curl -fsS -X POST "http://127.0.0.1:$PORT/eve/v1/session/$session" -H 'content-type: application/json' -d '{"message":"What is my favorite city?"}' >/dev/null || fail "old follow-up failed"
sleep 8
stop_server

EVE_NEW_TARBALL="$(npm view "eve@$NEW_EVE" dist.tarball)"
npm install --no-audit --no-fund --save-exact "$EVE_NEW_TARBALL" >/dev/null
./node_modules/.bin/eve build >/dev/null || fail "new build failed"
start_server
resume=$(curl -sS -X POST "http://127.0.0.1:$PORT/eve/v1/session/$session" -H 'content-type: application/json' -d '{"message":"What is my favorite city now?"}')
echo "Resume response: $resume"
sleep 5

status=$(docker exec eve-repro-pg psql -U eve -d "$DB" -F '|' -At -c "SELECT status || '|' || COALESCE(error_code, '') FROM workflow.workflow_runs WHERE name = 'workflowEntry'" 2>/dev/null || true)
echo "Durable run status: $status"
grep -q 'failed|CORRUPTED_EVENT_LOG' <<<"$status" || fail "durable run did not reach CORRUPTED_EVENT_LOG"
echo "PASS: parked session became non-resumable after the Eve version upgrade."
