#!/usr/bin/env bash
# render-html.sh — Render an HTML file to PNG screenshot(s) via headless Chromium.
#
# Purpose: enable Claude (or anyone) to visually inspect a rendered HTML artifact
# instead of only reading the source. Claude reads PNGs natively (multimodal),
# so this closes the loop "edit HTML → see result" without leaving the agent.
#
# Usage:
#   render-html.sh <path/to/file.html>                    # desktop only (1280x4200)
#   render-html.sh <path/to/file.html> all                # desktop + mobile + print
#   render-html.sh <path/to/file.html> desktop|mobile|print
#
# Output:
#   /tmp/render-<basename>-<viewport>.png
#   Prints absolute paths of generated PNGs to stdout (one per line) so the caller
#   can pipe directly into a Read tool invocation.
#
# Requirements:
#   - chromium (or chrome) on PATH
#
# Why headless instead of a real browser:
#   - reproducible (no profile/cache state)
#   - no display server needed (works in remote/SSH/agent contexts)
#   - --window-size controls the viewport so we capture full-page screenshots
#     (Chromium auto-extends height up to window-size to fit content)

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <html-path> [desktop|mobile|print|all]" >&2
  exit 2
fi

html_path="$1"
viewport="${2:-desktop}"

if [[ ! -f "$html_path" ]]; then
  echo "File not found: $html_path" >&2
  exit 1
fi

abs_path="$(realpath "$html_path")"
base="$(basename "$html_path" .html)"

browser=""
for candidate in chromium chromium-browser google-chrome chrome; do
  if command -v "$candidate" >/dev/null 2>&1; then
    browser="$candidate"
    break
  fi
done
if [[ -z "$browser" ]]; then
  echo "No Chromium/Chrome found on PATH" >&2
  exit 1
fi

shoot() {
  local name="$1" w="$2" h="$3" extra="${4:-}"
  local out="/tmp/render-${base}-${name}.png"
  # shellcheck disable=SC2086
  "$browser" \
    --headless \
    --disable-gpu \
    --no-sandbox \
    --hide-scrollbars \
    --window-size="${w},${h}" \
    $extra \
    --screenshot="$out" \
    "file://${abs_path}" >/dev/null 2>&1
  echo "$out"
}

case "$viewport" in
  desktop) shoot desktop 1280 4200 ;;
  mobile)  shoot mobile 420 6000 ;;
  print)   shoot print 794 4200 "--force-device-scale-factor=1" ;;  # ~A4 width @ 96dpi
  all)
    shoot desktop 1280 4200
    shoot mobile 420 6000
    shoot print 794 4200 "--force-device-scale-factor=1"
    ;;
  *)
    echo "Unknown viewport: $viewport (use desktop|mobile|print|all)" >&2
    exit 2
    ;;
esac
