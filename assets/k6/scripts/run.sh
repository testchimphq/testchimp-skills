#!/usr/bin/env bash
# Suite runner (Playwright analog). Invoke from the SmartTests / tests root
# (parent of k6/):
#
#   k6/scripts/run.sh
#   k6/scripts/run.sh journeys/foo.js journeys/nested/bar.js
#   k6/scripts/run.sh composites/peak.js
#   k6/scripts/run.sh --impacted
#
# Args are paths relative to k6/. Bare filenames and a k6/ prefix are errors.
# Dispatch: testTypes load (default) vs volume. Dual-tag: load then volume.
# --impacted reads plans/smart-smoke/<branch>/related-perf-tests.json.
set -uo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SMART_ROOT="$(CDPATH= cd -- "$ROOT/.." && pwd)"

usage() {
  echo "usage: k6/scripts/run.sh [--impacted] [journeys/file.js …]" >&2
  echo "  no args     all journeys under k6/journeys/ (recursive)" >&2
  echo "  paths       k6-relative, e.g. journeys/foo.js (never bare foo.js)" >&2
  echo "  --impacted  plans/smart-smoke/<branch>/related-perf-tests.json" >&2
  echo "              missing file: warn and run all journeys (PERF_IMPACTED_STRICT=1 to fail)" >&2
  echo "              selected: []: nothing to run" >&2
  exit "${1:-1}"
}

IMPACTED=0
PATHS=()
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage 0 ;;
    --impacted) IMPACTED=1 ;;
    -*)
      echo "unknown flag: $arg" >&2
      usage
      ;;
    *) PATHS+=("$arg") ;;
  esac
done

if [ "$IMPACTED" = 1 ] && [ "${#PATHS[@]}" -gt 0 ]; then
  echo "k6/scripts/run.sh: --impacted cannot be combined with file args" >&2
  usage
fi

BRANCH="${TESTCHIMP_BRANCH_NAME:-}"
if [ -z "$BRANCH" ] && command -v git >/dev/null 2>&1; then
  BRANCH="$(git -C "$SMART_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

PLANS="${TESTCHIMP_PLANS_ROOT:-}"
if [ -z "$PLANS" ] && [ -d "$SMART_ROOT/plans" ]; then
  PLANS="$SMART_ROOT/plans"
elif [ -z "$PLANS" ] && [ -d "$SMART_ROOT/../plans" ]; then
  PLANS="$(CDPATH= cd -- "$SMART_ROOT/../plans" && pwd)"
fi

TC_SUITE_PATHS=""
if [ "${#PATHS[@]}" -gt 0 ]; then
  TC_SUITE_PATHS="$(printf '%s\n' "${PATHS[@]}")"
fi
PLANS="${PLANS:-}"
STRICT="${PERF_IMPACTED_STRICT:-}"
SMOKE="$([ "${K6_PROFILE:-}" = smoke ] && echo 1 || echo 0)"
export IMPACTED BRANCH PLANS STRICT SMOKE TC_SUITE_PATHS

if ! command -v python3 >/dev/null 2>&1; then
  echo "k6/scripts/run.sh: python3 is required" >&2
  exit 1
fi

WORKLIST="$(python3 "$ROOT/scripts/suite-worklist.py" "$ROOT")"
py_status=$?
if [ "$py_status" -ne 0 ]; then
  exit "$py_status"
fi

if [ -z "$WORKLIST" ]; then
  if [ "$IMPACTED" = 1 ]; then
    echo "k6/scripts/run.sh --impacted: no related journeys" >&2
  else
    echo "k6/scripts/run.sh: no journeys to run" >&2
  fi
  exit 0
fi

if [ -z "${TESTCHIMP_BATCH_INVOCATION_ID:-}" ]; then
  if command -v uuidgen >/dev/null 2>&1; then
    TESTCHIMP_BATCH_INVOCATION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  else
    TESTCHIMP_BATCH_INVOCATION_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  fi
  export TESTCHIMP_BATCH_INVOCATION_ID
  echo "k6/scripts/run.sh: TESTCHIMP_BATCH_INVOCATION_ID=$TESTCHIMP_BATCH_INVOCATION_ID"
fi

echo "=== k6/scripts/run.sh prepare ==="
if ! "$ROOT/scripts/prepare.sh"; then
  echo "k6/scripts/run.sh: prepare.sh failed" >&2
  exit 1
fi
export K6_SKIP_PREPARE=1

TAB=$'\t'
FAILED=0
FAIL_NAMES=()

run_wrapper() {
  local rel="$1"
  if [[ "$rel" == composites/* ]]; then
    "$ROOT/scripts/run-composite.sh" "$rel"
  else
    "$ROOT/scripts/run-journey.sh" "$rel"
  fi
}

run_volume() {
  local rel="$1"
  local kind="$2"
  if [ -z "$kind" ]; then
    echo "volume journey missing testchimp.volumeKind: $rel" >&2
    return 1
  fi
  local m10="datasets/volume-${kind}-10.json"
  local m50="datasets/volume-${kind}-50.json"
  local m100="datasets/volume-${kind}-100.json"
  local m
  for m in "$m10" "$m50" "$m100"; do
    if [ ! -f "$ROOT/$m" ]; then
      echo "missing volume dataset $m for $rel (volumeKind=$kind)" >&2
      return 1
    fi
  done
  echo "=== volume $rel kind=$kind ==="
  "$ROOT/scripts/run-volume-staircase.sh" "$rel" "$m10" "$m50" "$m100"
}

SMOKE_N=0
LOAD_N=0
VOLUME_N=0

while IFS= read -r line; do
  [ -n "$line" ] || continue
  action="${line%%${TAB}*}"
  rest="${line#*${TAB}}"
  case "$action" in
    FAIL)
      rel="${rest%%${TAB}*}"
      reason="${rest#*${TAB}}"
      echo "failed $rel ($reason)" >&2
      FAILED=1
      FAIL_NAMES+=("$rel")
      ;;
    SMOKE)
      SMOKE_N=$((SMOKE_N + 1))
      echo "=== smoke $rest ==="
      export K6_PROFILE=smoke
      if ! run_wrapper "$rest"; then
        FAILED=1
        FAIL_NAMES+=("$rest")
      fi
      ;;
    LOAD)
      LOAD_N=$((LOAD_N + 1))
      echo "=== load $rest ==="
      export K6_PROFILE=load
      if ! run_wrapper "$rest"; then
        FAILED=1
        FAIL_NAMES+=("$rest")
      fi
      ;;
    VOLUME)
      : # second pass
      ;;
    *)
      echo "internal: unknown worklist row: $line" >&2
      FAILED=1
      ;;
  esac
done <<< "$WORKLIST"

# Volume after all load (shared env: keep DB small until seeding).
while IFS= read -r line; do
  [ -n "$line" ] || continue
  action="${line%%${TAB}*}"
  [ "$action" = "VOLUME" ] || continue
  rest="${line#*${TAB}}"
  rel="${rest%%${TAB}*}"
  kind="${rest#*${TAB}}"
  VOLUME_N=$((VOLUME_N + 1))
  if ! run_volume "$rel" "$kind"; then
    FAILED=1
    FAIL_NAMES+=("$rel")
  fi
done <<< "$WORKLIST"

echo "=== k6/scripts/run.sh summary smoke=$SMOKE_N load=$LOAD_N volume=$VOLUME_N ==="
if [ "$FAILED" -ne 0 ]; then
  printf 'failed: %s\n' "${FAIL_NAMES[@]}" >&2
  exit 1
fi
exit 0
