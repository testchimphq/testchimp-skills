#!/usr/bin/env bash
# Run one k6 journey or composite (one k6 run). Usage: run-journey.sh k6/journeys/checkout.js
set -euo pipefail
SCRIPT="${1:?usage: run-journey.sh <path-to-k6-script>}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# Allow calling with path relative to SmartTests root or to k6/
if [ ! -f "$SCRIPT" ]; then
  if [ -f "$ROOT/../$SCRIPT" ]; then
    SCRIPT="$ROOT/../$SCRIPT"
  elif [ -f "$ROOT/$SCRIPT" ]; then
    SCRIPT="$ROOT/$SCRIPT"
  fi
fi
if [ ! -f "$SCRIPT" ]; then
  echo "k6 script not found: $1" >&2
  exit 1
fi
if [ ! -f "$ROOT/lib/handleSummary.js" ]; then
  "$ROOT/scripts/prepare.sh"
fi
ABS="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
DIR="$(cd "$(dirname "$ABS")" && pwd)"
# folder path relative to SmartTests root (parent of k6/)
SMART_ROOT="$(cd "$ROOT/.." && pwd)"
FOLDER_REL="${DIR#"$SMART_ROOT"/}"
export TESTCHIMP_FOLDER_PATH="${TESTCHIMP_FOLDER_PATH:-$FOLDER_REL}"
export TESTCHIMP_FILE_NAME="${TESTCHIMP_FILE_NAME:-$(basename "$ABS")}"

extract_quoted_field() {
  local field="$1"
  grep -E "${field}:[[:space:]]*['\"][^'\"]+" "$ABS" | head -1 \
    | sed -E "s/.*${field}:[[:space:]]*['\"]([^'\"]+).*/\1/" || true
}

extract_array_field() {
  local field="$1"
  local line
  line="$(grep -E "${field}:[[:space:]]*\[" "$ABS" | head -1 || true)"
  if [ -z "$line" ]; then
    return 0
  fi
  echo "$line" | sed -E "s/.*\[//;s/\].*//;s/['\"]//g;s/[[:space:]]//g"
}

if command -v python3 >/dev/null 2>&1; then
  EXTRACTED_ENV=$(python3 "$ROOT/scripts/extract-testchimp-meta.py" "$ABS" || true)
  eval "$EXTRACTED_ENV"
fi
export TESTCHIMP_PERF_ID="${TESTCHIMP_PERF_ID:-${EXTRACTED_PERF_ID:-$(extract_quoted_field id)}}"
export TESTCHIMP_PERF_KIND="${TESTCHIMP_PERF_KIND:-${EXTRACTED_PERF_KIND:-$(extract_quoted_field kind)}}"
export TESTCHIMP_PERF_TEST_TYPES="${TESTCHIMP_PERF_TEST_TYPES:-${EXTRACTED_PERF_TEST_TYPES:-$(extract_array_field testTypes)}}"
export TESTCHIMP_PERF_SCENARIOS="${TESTCHIMP_PERF_SCENARIOS:-${EXTRACTED_PERF_SCENARIOS:-$(extract_array_field scenarios)}}"
export TESTCHIMP_PERF_MEMBERS="${TESTCHIMP_PERF_MEMBERS:-${EXTRACTED_PERF_MEMBERS:-$(extract_array_field members)}}"

if [ -z "${TESTCHIMP_PERF_META:-}" ]; then
  if command -v python3 >/dev/null 2>&1; then
    export TESTCHIMP_PERF_META
    TESTCHIMP_PERF_META="$(python3 - <<'PY'
import json, os
def csv(name):
    return [p for p in os.environ.get(name, "").split(",") if p]
print(json.dumps({
    "id": os.environ.get("TESTCHIMP_PERF_ID", ""),
    "kind": os.environ.get("TESTCHIMP_PERF_KIND", ""),
    "folderPath": os.environ.get("TESTCHIMP_FOLDER_PATH", ""),
    "fileName": os.environ.get("TESTCHIMP_FILE_NAME", ""),
    "testTypes": csv("TESTCHIMP_PERF_TEST_TYPES"),
    "scenarios": csv("TESTCHIMP_PERF_SCENARIOS"),
    "members": csv("TESTCHIMP_PERF_MEMBERS"),
}))
PY
)"
  fi
fi

if [ -z "${TESTCHIMP_BRANCH_NAME:-}" ] && command -v git >/dev/null 2>&1; then
  export TESTCHIMP_BRANCH_NAME="$(git -C "$SMART_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi
export TESTCHIMP_PERF_PROFILE="${TESTCHIMP_PERF_PROFILE:-${K6_PROFILE:-smoke}}"
export TESTCHIMP_LLM_MODE="${TESTCHIMP_LLM_MODE:-${LLM_MODE:-mock}}"
if [ -z "${TESTCHIMP_GIT_COMMIT_SHA:-}" ] && command -v git >/dev/null 2>&1; then
  export TESTCHIMP_GIT_COMMIT_SHA="$(git -C "$SMART_ROOT" rev-parse HEAD 2>/dev/null || true)"
fi
if [ -z "${TESTCHIMP_PERF_DATASET:-}" ] && [ -n "${K6_DATASET:-}" ]; then
  DATASET="$K6_DATASET"
  if [ ! -f "$DATASET" ] && [ -f "$SMART_ROOT/$DATASET" ]; then
    DATASET="$SMART_ROOT/$DATASET"
  fi
  if [ ! -f "$DATASET" ]; then
    echo "K6_DATASET not found: $K6_DATASET" >&2
    exit 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    export TESTCHIMP_PERF_DATASET
    TESTCHIMP_PERF_DATASET=$(python3 - "$DATASET" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
print(data.get("id", ""))
PY
)
  else
    export TESTCHIMP_PERF_DATASET="$(basename "$DATASET")"
  fi
fi
exec k6 run "$ABS"
