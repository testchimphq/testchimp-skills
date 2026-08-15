#!/usr/bin/env bash
# Run one composite through the common metadata/ingest wrapper.
set -euo pipefail

SCRIPT="${1:?usage: run-composite.sh <k6/composites/file.js>}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

if [ ! -f "$SCRIPT" ] && [ -f "$ROOT/../$SCRIPT" ]; then
  SCRIPT="$ROOT/../$SCRIPT"
elif [ ! -f "$SCRIPT" ] && [ -f "$ROOT/$SCRIPT" ]; then
  SCRIPT="$ROOT/$SCRIPT"
fi
if [ ! -f "$SCRIPT" ]; then
  echo "composite not found: $1" >&2
  exit 1
fi
if ! grep -Eq "kind:[[:space:]]*['\"]composite['\"]" "$SCRIPT"; then
  echo "expected testchimp.kind 'composite': $SCRIPT" >&2
  exit 1
fi

exec "$ROOT/scripts/run-journey.sh" "$SCRIPT"
