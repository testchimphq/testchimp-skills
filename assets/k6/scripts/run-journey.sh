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
# Always refresh @testchimp/k6 unless the suite runner already did (K6_SKIP_PREPARE=1).
if [ "${K6_SKIP_PREPARE:-}" != "1" ]; then
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

# Timeseries: k6 JSON out → downsample → attach by run_id sidecar from handleSummary.
PERF_TMP="$(mktemp -d "${TMPDIR:-/tmp}/testchimp-perf.XXXXXX")"
cleanup_perf_tmp() { rm -rf "$PERF_TMP"; }
trap cleanup_perf_tmp EXIT
export TESTCHIMP_PERF_RUN_ID_FILE="$PERF_TMP/run-id"
METRICS_JSON="$PERF_TMP/metrics.json"
K6_STDOUT="$PERF_TMP/k6.stdout"
INTERVAL_SEC="${TESTCHIMP_PERF_TIMESERIES_INTERVAL_SEC:-5}"

set +e
k6 run --out "json=$METRICS_JSON" "$ABS" | tee "$K6_STDOUT"
K6_EXIT=${PIPESTATUS[0]}
set -e

RUN_ID=""
if [ -f "$TESTCHIMP_PERF_RUN_ID_FILE" ]; then
  RUN_ID="$(tr -d '[:space:]' <"$TESTCHIMP_PERF_RUN_ID_FILE" || true)"
fi
if [ -z "$RUN_ID" ] && [ -f "$K6_STDOUT" ]; then
  RUN_ID="$(grep -Eo 'runId=[0-9a-fA-F-]{8,}' "$K6_STDOUT" | tail -1 | cut -d= -f2 || true)"
fi

if [ -n "$RUN_ID" ] && [ -f "$METRICS_JSON" ] && command -v node >/dev/null 2>&1; then
  DOWNSAMPLE_JS=""
  if [ -f "$ROOT/lib/downsample.js" ]; then
    DOWNSAMPLE_JS="$ROOT/lib/downsample.js"
  elif [ -n "${K6_REPORTER_LOCAL_DIR:-}" ] && [ -f "${K6_REPORTER_LOCAL_DIR}/downsample.js" ]; then
    DOWNSAMPLE_JS="${K6_REPORTER_LOCAL_DIR}/downsample.js"
  fi
  if [ -z "$DOWNSAMPLE_JS" ]; then
    echo "TestChimp timeseries skipped: downsample.js not found. Re-run k6/scripts/prepare.sh (npm latest @testchimp/k6)." >&2
  else
    node --input-type=module - "$DOWNSAMPLE_JS" "$METRICS_JSON" "$RUN_ID" "$INTERVAL_SEC" <<'NODE' || true
import { pathToFileURL } from 'node:url';

const [modPath, metricsPath, runId, intervalSec] = process.argv.slice(2);
const mod = await import(pathToFileURL(modPath).href);
const result = mod.downsampleK6JsonMetrics(metricsPath, {
  intervalSec: Number(intervalSec) || 5,
  maxPoints: 500,
});
const attach = await mod.postTimeseriesAttach(process.env, runId, result);
if (attach.attached) {
  console.error(`TestChimp timeseries attach ok (${attach.statusCode}) points=${(result.points || []).length}`);
} else if (attach.reason === 'no-points') {
  console.error('TestChimp timeseries: no points after downsample');
} else {
  console.error(`TestChimp timeseries attach failed (${attach.reason || 'unknown'}) ${attach.body || ''}`);
}
NODE
  fi
elif [ -z "$RUN_ID" ]; then
  echo "TestChimp timeseries skipped: no ingest runId (sidecar or stdout). Charts will be missing for this run." >&2
fi

exit "$K6_EXIT"
