#!/usr/bin/env bash
# Refresh @testchimp/k6 into k6/lib (gitignored). Never vendor a copy in git.
# Default: always download npm @latest so a new publish reaches users on the
# next prepare / run. Override with K6_REPORTER_VERSION=<semver> to pin.
# Keep original filenames so handleSummary.js can import ./ingest.js.
set -euo pipefail
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/lib"
mkdir -p "$LIB"

# "latest" = whatever npm currently publishes as latest.
REQUESTED="${K6_REPORTER_VERSION:-latest}"

resolve_version() {
  local requested="$1"
  if [ "$requested" != "latest" ]; then
    echo "$requested"
    return 0
  fi
  if command -v npm >/dev/null 2>&1; then
    local resolved
    resolved="$(npm view @testchimp/k6 version 2>/dev/null || true)"
    if [ -n "$resolved" ]; then
      echo "$resolved"
      return 0
    fi
  fi
  # jsDelivr accepts @latest; stamp file will record "latest" if npm is offline.
  echo "latest"
}

VERSION="$(resolve_version "$REQUESTED")"

pin_from_dir() {
  local src="$1"
  if [ ! -f "$src/handleSummary.js" ] || [ ! -f "$src/ingest.js" ]; then
    echo "K6_REPORTER_LOCAL_DIR is missing handleSummary.js or ingest.js: $src" >&2
    exit 1
  fi
  cp "$src/handleSummary.js" "$LIB/handleSummary.js"
  cp "$src/ingest.js" "$LIB/ingest.js"
  if [ -f "$src/downsample.js" ]; then
    cp "$src/downsample.js" "$LIB/downsample.js"
  fi
  if [ -f "$src/package.json" ] && command -v node >/dev/null 2>&1; then
    node -e 'const p=require(process.argv[1]); process.stdout.write(p.version||"local")' \
      "$src/package.json" >"$LIB/.version"
  else
    echo "local" >"$LIB/.version"
  fi
}

pin_from_cdn() {
  local version="$1"
  local base="https://cdn.jsdelivr.net/npm/@testchimp/k6@${version}"
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  if curl -fsSL "$base/handleSummary.js" -o "$tmp/handleSummary.js" \
      && curl -fsSL "$base/ingest.js" -o "$tmp/ingest.js"; then
    cp "$tmp/handleSummary.js" "$LIB/handleSummary.js"
    cp "$tmp/ingest.js" "$LIB/ingest.js"
    if curl -fsSL "$base/downsample.js" -o "$tmp/downsample.js"; then
      cp "$tmp/downsample.js" "$LIB/downsample.js"
    else
      echo "Warning: downsample.js is not on CDN for @testchimp/k6@${version}." >&2
      echo "Timeseries charts need it — pin a local checkout: K6_REPORTER_LOCAL_DIR=/path/to/k6-testchimp-reporter" >&2
    fi
    echo "$version" >"$LIB/.version"
  else
    echo "Failed to download @testchimp/k6@${version} from jsDelivr." >&2
    echo "Until the package is published, pin a local checkout:" >&2
    echo "  K6_REPORTER_LOCAL_DIR=/path/to/k6-testchimp-reporter k6/scripts/prepare.sh" >&2
    echo "To pin a specific release: K6_REPORTER_VERSION=0.1.0 k6/scripts/prepare.sh" >&2
    exit 1
  fi
  trap - EXIT
  rm -rf "$tmp"
}

if [ -n "${K6_REPORTER_LOCAL_DIR:-}" ]; then
  pin_from_dir "$K6_REPORTER_LOCAL_DIR"
elif [ "${K6_REPORTER_SKIP_REFRESH:-}" = "1" ] \
    && [ -f "$LIB/handleSummary.js" ] && [ -f "$LIB/ingest.js" ]; then
  echo "Skipped refresh (K6_REPORTER_SKIP_REFRESH=1); using $LIB ($(cat "$LIB/.version" 2>/dev/null || echo unknown))"
  exit 0
else
  pin_from_cdn "$VERSION"
fi
echo "Pinned @testchimp/k6@$(cat "$LIB/.version") -> $LIB"
