#!/usr/bin/env bash
# Deterministically select journeys from changed scenarios/operations/paths.
set -euo pipefail

INPUT="${1:?usage: select-related.sh <changes.json> [output.json]}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
if [ ! -f "$INPUT" ]; then
  echo "change input not found: $INPUT" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for related selection" >&2
  exit 1
fi

BRANCH="$(python3 - "$INPUT" <<'PY'
import json, re, sys
branch = str(json.load(open(sys.argv[1], encoding="utf-8")).get("branch", "unknown"))
print(re.sub(r"[^A-Za-z0-9._-]+", "-", branch).strip("-") or "unknown")
PY
)"
OUTPUT="${2:-$ROOT/artifacts/related/$BRANCH/related-perf-tests.json}"
mkdir -p "$(dirname "$OUTPUT")"

python3 - "$INPUT" "$ROOT/journeys" "$OUTPUT" <<'PY'
import hashlib, json, pathlib, re, sys

input_path, journey_dir, output_path = map(pathlib.Path, sys.argv[1:])
changes = json.loads(input_path.read_text(encoding="utf-8"))

def normalized(name):
    value = changes.get(name, [])
    if not isinstance(value, list):
        raise SystemExit(f"{name} must be an array")
    return sorted({str(item) for item in value if str(item)})

wanted = {
    "scenarios": normalized("scenarios"),
    "operations": normalized("operations"),
    "paths": normalized("paths"),
}
canonical = json.dumps(changes, sort_keys=True, separators=(",", ":")).encode()

def array(source, field):
    match = re.search(rf"\b{field}\s*:\s*\[([^\]]*)\]", source)
    return re.findall(r"['\"]([^'\"]+)['\"]", match.group(1)) if match else []

def scalar(source, field):
    match = re.search(rf"\b{field}\s*:\s*['\"]([^'\"]+)['\"]", source)
    return match.group(1) if match else ""

selected = []
for path in sorted(journey_dir.glob("*.js")):
    source = path.read_text(encoding="utf-8")
    journey_id = scalar(source, "id")
    if not journey_id or scalar(source, "kind") != "journey":
        continue
    reasons = []
    for field in ("scenarios", "operations", "paths"):
        overlap = sorted(set(array(source, field)) & set(wanted[field]))
        reasons.extend(f"{field[:-1]}:{item}" for item in overlap)
    if reasons:
        selected.append({
            "id": journey_id,
            "file": f"k6/journeys/{path.name}",
            "reasons": sorted(reasons),
        })

artifact = {
    "schemaVersion": 1,
    "branch": str(changes.get("branch", "")),
    "inputSha256": hashlib.sha256(canonical).hexdigest(),
    "selected": sorted(selected, key=lambda item: (item["id"], item["file"])),
}
pathlib.Path(output_path).write_text(
    json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)
PY

printf 'Wrote related selection: %s\n' "$OUTPUT"
