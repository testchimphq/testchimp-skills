#!/usr/bin/env bash
# Pin @testchimp/k6 into k6/lib (gitignored). Never vendor a copy in git.
# Keep original filenames so handleSummary.js can import ./ingest.js (no sed rewrite).
set -euo pipefail
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
VERSION="${K6_REPORTER_VERSION:-0.1.0}"
LIB="$ROOT/lib"
mkdir -p "$LIB"

pin_from_dir() {
  local src="$1"
  if [ ! -f "$src/handleSummary.js" ] || [ ! -f "$src/ingest.js" ]; then
    echo "K6_REPORTER_LOCAL_DIR is missing handleSummary.js or ingest.js: $src" >&2
    exit 1
  fi
  cp "$src/handleSummary.js" "$LIB/handleSummary.js"
  cp "$src/ingest.js" "$LIB/ingest.js"
}

if [ -n "${K6_REPORTER_LOCAL_DIR:-}" ]; then
  pin_from_dir "$K6_REPORTER_LOCAL_DIR"
else
  BASE="https://cdn.jsdelivr.net/npm/@testchimp/k6@${VERSION}"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  if curl -fsSL "$BASE/handleSummary.js" -o "$TMP/handleSummary.js" \
      && curl -fsSL "$BASE/ingest.js" -o "$TMP/ingest.js"; then
    cp "$TMP/handleSummary.js" "$LIB/handleSummary.js"
    cp "$TMP/ingest.js" "$LIB/ingest.js"
  else
    echo "Failed to download @testchimp/k6@${VERSION} from jsDelivr." >&2
    echo "Until the package is published, pin a local checkout:" >&2
    echo "  K6_REPORTER_LOCAL_DIR=/path/to/k6-testchimp-reporter k6/scripts/prepare.sh" >&2
    exit 1
  fi
fi
echo "Pinned @testchimp/k6@${VERSION} -> $LIB"
