#!/usr/bin/env bash
# Volume staircase: seed each cardinality, then ONE k6 run that holds 1 VU at
# each size and emits volume_size (Executions charts that instead of VUs).
#
# Internal helper — called by k6/scripts/run.sh only. Do not invoke from CI
# or playbooks; users/CI use run.sh (paths relative to k6/).
#
# Usage:
#   run-volume-staircase.sh <k6/journeys/foo.js> <manifest-10.json> [manifest-50.json ...]
#   run-volume-staircase.sh <journey-stem> <volumeKind>
#     → journeys/<stem>.js + datasets/volume-<kind>-{10,50,100}.json
#
# Env:
#   SEED_COMMAND     required (or seed.sh's SEED_COMMAND / SEED_URL)
#   RUN_JOURNEY      default: this k6/scripts/run-journey.sh
#   TEARDOWN_COMMAND optional; always runs after k6 (even on fail)
#   PERF_TENANTS_FILE default: k6/artifacts/seed/tenants.json
#   K6_VOLUME_STEP_DURATION / K6_VOLUME_DURATION  hold per step (default 1m)
#   PERF_ENV_FILE    optional file to `source` after seed (local creds)
#
# SEED_COMMAND contract: when PERF_SEED_APPEND=1, append tenants rather than
# replace PERF_TENANTS_FILE. Each tenant object MUST include numeric volumeSize
# of the data that VU will hit. Do not step the gauge without switching data.
set -euo pipefail
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SMART_ROOT="$(CDPATH= cd -- "$ROOT/.." && pwd)"

usage() {
  echo "usage: run-volume-staircase.sh <k6-script.js> <manifest.json> [manifest.json ...]" >&2
  echo "   or: run-volume-staircase.sh <journey-stem> <volumeKind>" >&2
  exit 1
}

resolve_under_k6() {
  local p="$1"
  if [ -f "$p" ]; then
    printf '%s\n' "$p"
    return
  fi
  if [ -f "$ROOT/$p" ]; then
    printf '%s\n' "$ROOT/$p"
    return
  fi
  if [ -f "$SMART_ROOT/$p" ]; then
    printf '%s\n' "$SMART_ROOT/$p"
    return
  fi
  return 1
}

[ "${1:-}" ] || usage

JOURNEY=""
MANIFESTS=()

if [[ "${1}" == *.js ]]; then
  JOURNEY="$(resolve_under_k6 "$1" || true)"
  shift
  [ "$#" -ge 1 ] || usage
  for m in "$@"; do
    MANIFESTS+=("$(resolve_under_k6 "$m")")
  done
else
  STEM="$1"
  KIND="${2:?}"
  [ -n "$KIND" ] || usage
  JOURNEY="$(
    resolve_under_k6 "journeys/${STEM}.js" \
      || resolve_under_k6 "k6/journeys/${STEM}.js" \
      || resolve_under_k6 "journeys/${STEM}-journey.js" \
      || resolve_under_k6 "k6/journeys/${STEM}-journey.js" \
      || true
  )"
  for pct in 10 50 100; do
    MANIFESTS+=("$(resolve_under_k6 "datasets/volume-${KIND}-${pct}.json" || resolve_under_k6 "k6/datasets/volume-${KIND}-${pct}.json")")
  done
fi

if [ -z "${JOURNEY:-}" ] || [ ! -f "$JOURNEY" ]; then
  echo "journey not found" >&2
  exit 1
fi
if [ "${#MANIFESTS[@]}" -lt 1 ]; then
  echo "at least one volume dataset manifest is required" >&2
  exit 1
fi

export K6_PROFILE=volume
unset K6_LOAD_VUS
TENANTS_FILE="${PERF_TENANTS_FILE:-$ROOT/artifacts/seed/tenants.json}"
export PERF_TENANTS_FILE="$TENANTS_FILE"
mkdir -p "$(dirname "$TENANTS_FILE")"
rm -f "$TENANTS_FILE"
export PERF_SEED_APPEND=1

SEED_SH="$ROOT/scripts/seed.sh"
if [ ! -x "$SEED_SH" ]; then
  echo "missing $SEED_SH" >&2
  exit 1
fi

for MANIFEST in "${MANIFESTS[@]}"; do
  echo "=== volume staircase seed ${MANIFEST} ==="
  "$SEED_SH" "$MANIFEST"
done

if [ -n "${PERF_ENV_FILE:-}" ] && [ -f "$PERF_ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$PERF_ENV_FILE"
  export PERF_TENANTS_FILE="${PERF_TENANTS_FILE:-$TENANTS_FILE}"
fi

export K6_VOLUME_STEPS
K6_VOLUME_STEPS="$(python3 - "$PERF_TENANTS_FILE" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit("missing tenants file: " + str(path))
data = json.loads(path.read_text(encoding="utf-8"))
tenants = data if isinstance(data, list) else (data.get("tenants") or [])
sizes = [
    t.get("volumeSize")
    for t in tenants
    if isinstance((t or {}).get("volumeSize"), (int, float))
]
print(",".join(str(int(s)) for s in sizes))
PY
)"
if [ -z "$K6_VOLUME_STEPS" ]; then
  echo "volume staircase: SEED_COMMAND must append tenants with numeric volumeSize to $PERF_TENANTS_FILE" >&2
  echo "Do not emit a fake volume_size ramp against one unchanged dataset." >&2
  exit 1
fi

PEAK="${MANIFESTS[${#MANIFESTS[@]} - 1]}"
export K6_DATASET="$PEAK"
export K6_VOLUME_STEP_DURATION="${K6_VOLUME_STEP_DURATION:-${K6_VOLUME_DURATION:-1m}}"
RUN_JOURNEY="${RUN_JOURNEY:-$ROOT/scripts/run-journey.sh}"

echo "=== volume staircase run steps=${K6_VOLUME_STEPS} hold=${K6_VOLUME_STEP_DURATION} dataset=${K6_DATASET} ==="
set +e
"$RUN_JOURNEY" "$JOURNEY"
rc=$?
set -e
echo "staircase_exit=$rc steps=$K6_VOLUME_STEPS"
if [ -n "${TEARDOWN_COMMAND:-}" ]; then
  $TEARDOWN_COMMAND || true
fi
exit "$rc"
