#!/usr/bin/env bash
# Validate and apply one dataset manifest. Never guesses a product seed route.
set -euo pipefail

MANIFEST="${1:?usage: seed.sh <dataset-manifest.json>}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

if [ ! -f "$MANIFEST" ] && [ -f "$ROOT/$MANIFEST" ]; then
  MANIFEST="$ROOT/$MANIFEST"
fi
if [ ! -f "$MANIFEST" ]; then
  echo "dataset manifest not found: $MANIFEST" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to validate dataset manifests" >&2
  exit 1
fi

META="$(python3 - "$MANIFEST" <<'PY'
import hashlib, json, pathlib, sys
path = pathlib.Path(sys.argv[1])
raw = path.read_bytes()
data = json.loads(raw)
required = ("schemaVersion", "id", "kind", "seed", "teardownRequired")
missing = [key for key in required if key not in data]
if missing:
    raise SystemExit("missing dataset fields: " + ", ".join(missing))
if data["kind"] not in ("load", "volume"):
    raise SystemExit('dataset kind must be "load" or "volume"')
if not isinstance(data["seed"], dict):
    raise SystemExit("dataset seed must be an object")
if not isinstance(data["id"], str) or not data["id"] or any(
    char not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
    for char in data["id"]
):
    raise SystemExit("dataset id may contain only letters, numbers, dot, underscore, and hyphen")
print(json.dumps({
    "id": data["id"],
    "kind": data["kind"],
    "sha256": hashlib.sha256(raw).hexdigest(),
}, sort_keys=True, separators=(",", ":")))
PY
)"

if [ -n "${SEED_COMMAND:-}" ]; then
  if [ ! -x "$SEED_COMMAND" ]; then
    echo "SEED_COMMAND must name an executable file: $SEED_COMMAND" >&2
    exit 1
  fi
  "$SEED_COMMAND" "$MANIFEST"
elif [ -n "${SEED_URL:-}" ]; then
  command -v curl >/dev/null 2>&1 || {
    echo "curl is required when SEED_URL is used" >&2
    exit 1
  }
  curl -fsS -X POST -H 'Content-Type: application/json' \
    --data-binary "@$MANIFEST" "$SEED_URL" >/dev/null
else
  echo "Set SEED_COMMAND (executable receiving manifest path) or SEED_URL." >&2
  exit 1
fi

ARTIFACT_DIR="$ROOT/artifacts/seed"
mkdir -p "$ARTIFACT_DIR"
DATASET_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$META")"
printf '%s\n' "$META" >"$ARTIFACT_DIR/$DATASET_ID.json"
printf 'Seeded %s (%s)\n' "$DATASET_ID" "$MANIFEST"
