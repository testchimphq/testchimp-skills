#!/usr/bin/env bash
# Deterministically select journeys from changed scenarios/operations/paths.
# Default output: <plans>/smart-smoke/<branch>/related-perf-tests.json
# (sibling of related-tests.json). Paths in the artifact are k6-relative.
set -euo pipefail

INPUT="${1:?usage: select-related.sh <changes.json> [output.json]}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SMART_ROOT="$(CDPATH= cd -- "$ROOT/.." && pwd)"
if [ ! -f "$INPUT" ]; then
  echo "change input not found: $INPUT" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for related selection" >&2
  exit 1
fi

BRANCH="$(python3 - "$INPUT" <<'PY'
import json, sys
print(str(json.load(open(sys.argv[1], encoding="utf-8")).get("branch", "")).strip())
PY
)"
if [ -z "$BRANCH" ]; then
  BRANCH="${TESTCHIMP_BRANCH_NAME:-}"
fi
if [ -z "$BRANCH" ] && command -v git >/dev/null 2>&1; then
  BRANCH="$(git -C "$SMART_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi
if [ -z "$BRANCH" ] || [[ "$BRANCH" == *..* ]]; then
  echo "select-related.sh: set changes.branch or TESTCHIMP_BRANCH_NAME" >&2
  exit 1
fi

PLANS="${TESTCHIMP_PLANS_ROOT:-}"
if [ -z "$PLANS" ] && [ -d "$SMART_ROOT/plans" ]; then
  PLANS="$SMART_ROOT/plans"
elif [ -z "$PLANS" ] && [ -d "$SMART_ROOT/../plans" ]; then
  PLANS="$(CDPATH= cd -- "$SMART_ROOT/../plans" && pwd)"
fi

if [ -n "${2:-}" ]; then
  OUTPUT="$2"
elif [ -n "$PLANS" ]; then
  OUTPUT="$PLANS/smart-smoke/$BRANCH/related-perf-tests.json"
else
  echo "select-related.sh: pass an output path, or set TESTCHIMP_PLANS_ROOT" >&2
  exit 1
fi
mkdir -p "$(dirname "$OUTPUT")"

python3 - "$INPUT" "$ROOT" "$OUTPUT" "$BRANCH" <<'PY'
import hashlib, json, pathlib, re, sys

input_path, k6_root, output_path, branch = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3], sys.argv[4]
changes = json.loads(pathlib.Path(input_path).read_text(encoding="utf-8"))
if not changes.get("branch"):
    changes["branch"] = branch

def canon_scenario(item):
    text = str(item).strip()
    match = re.match(r"#?TS-?(\d+)$", text, re.I)
    return ("#TS-%s" % match.group(1)) if match else text

def canon_path(item):
    text = str(item).strip()
    if not text:
        return text
    if text.startswith("/") or "/" in text:
        if not text.startswith("/"):
            text = "/" + text
        if len(text) > 1:
            text = text.rstrip("/")
    return text

def normalized(name, mapper=None):
    value = changes.get(name, [])
    if not isinstance(value, list):
        raise SystemExit(f"{name} must be an array")
    mapped = [(mapper or (lambda x: str(x).strip()))(item) for item in value]
    return sorted({item for item in mapped if item})

wanted = {
    "scenarios": set(normalized("scenarios", canon_scenario)),
    "operations": set(normalized("operations")),
    "paths": set(normalized("paths", canon_path)),
}
canonical = json.dumps(changes, sort_keys=True, separators=(",", ":")).encode()

def testchimp_block(source):
    match = re.search(r"export\s+const\s+testchimp\s*=\s*\{", source)
    if not match:
        return ""
    start = match.end() - 1
    depth = 0
    for i, ch in enumerate(source[start:], start=start):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[start : i + 1]
    return ""

def array(block, field):
    found = re.search(rf"{field}\s*:\s*\[(.*?)\]", block, re.S)
    if not found:
        return []
    return re.findall(r"""['"]([^'"]+)['"]""", found.group(1))

def scalar(block, field):
    found = re.search(rf"""{field}\s*:\s*['"]([^'"]+)['"]""", block)
    return found.group(1) if found else ""

selected = []
journeys = k6_root / "journeys"
if journeys.is_dir():
    for path in sorted(journeys.rglob("*.js")):
        block = testchimp_block(path.read_text(encoding="utf-8"))
        journey_id = scalar(block, "id")
        if not journey_id or scalar(block, "kind") != "journey":
            continue
        journey_values = {
            "scenarios": [canon_scenario(item) for item in array(block, "scenarios")],
            "operations": [str(item).strip() for item in array(block, "operations")],
            "paths": [canon_path(item) for item in array(block, "paths")],
        }
        reasons = []
        for field in ("scenarios", "operations", "paths"):
            overlap = sorted(set(journey_values[field]) & wanted[field])
            reasons.extend("%s:%s" % (field[:-1], item) for item in overlap)
        if reasons:
            selected.append({
                "id": journey_id,
                "file": path.relative_to(k6_root).as_posix(),
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
