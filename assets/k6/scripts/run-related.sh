#!/usr/bin/env bash
# Run every journey in a deterministic related-selection artifact.
set -euo pipefail

ARTIFACT="${1:?usage: run-related.sh <related-perf-tests.json>}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SMART_ROOT="$(CDPATH= cd -- "$ROOT/.." && pwd)"

if [ ! -f "$ARTIFACT" ]; then
  echo "related selection not found: $ARTIFACT" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to read related selections" >&2
  exit 1
fi

export TESTCHIMP_BATCH_INVOCATION_ID
TESTCHIMP_BATCH_INVOCATION_ID="$(python3 - "$ARTIFACT" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data.get("schemaVersion") != 1:
    raise SystemExit("unsupported related selection schemaVersion")
print("related-" + str(data.get("inputSha256", ""))[:16])
PY
)"

FILES="$(python3 - "$ARTIFACT" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
for item in data.get("selected", []):
    path = str(item.get("file", ""))
    if "\n" in path:
        raise SystemExit("invalid newline in selected file")
    if path:
        print(path)
PY
)"

if [ -z "$FILES" ]; then
  echo "related selection is empty; nothing to run"
  exit 0
fi

while IFS= read -r file; do
  case "$file" in
    *..*)
      echo "refusing traversal in artifact path: $file" >&2
      exit 1
      ;;
    k6/journeys/*.js) ;;
    *)
      echo "refusing non-journey artifact path: $file" >&2
      exit 1
      ;;
  esac
  "$ROOT/scripts/run-journey.sh" "$SMART_ROOT/$file"
done <<EOF
$FILES
EOF
