#!/usr/bin/env bash
# Capture screenshots / PDFs of URLs (e.g. preview deployments) and download them into the workspace.
set -euo pipefail
. "$(dirname "$0")/apify.sh"
check_prereqs

URLS="$(split_list "${INPUT_URLS:-}")"
[ "$(jq length <<<"$URLS")" -gt 0 ] || fail "Input 'urls' is required (separate several URLs with commas or new lines)"
DEVICES="$(split_list "${INPUT_DEVICES:-desktop}")"
FORMAT="${INPUT_FORMAT:-png}"

BASE="$(jq -c -n --argjson urls "$URLS" --argjson dev "$DEVICES" --arg fmt "$FORMAT" \
  --arg cap "${INPUT_CAPTURE_MODE:-fullPage}" --arg wait "${INPUT_WAIT_UNTIL:-load}" \
  --argjson delay "${INPUT_DELAY_MS:-0}" --arg scheme "${INPUT_COLOR_SCHEME:-light}" \
  '{urls: $urls, devices: $dev, format: $fmt, captureMode: $cap, waitUntil: $wait, delayMs: $delay, colorScheme: $scheme}')"
INPUT="$(merge_extra "$BASE" "${INPUT_EXTRA_INPUT:-}")"

N="$(jq '(.urls | length) * ((.devices // ["desktop"]) | length)' <<<"$INPUT")"
CAP="${INPUT_MAX_TOTAL_CHARGE_USD:-}"
if [ -z "$CAP" ] || [ "$CAP" = "auto" ]; then
  CAP="$(awk -v n="$N" 'BEGIN{printf "%.3f", n*0.008+0.02}')"   # $0.008 per capture + margin
fi
DIR="${INPUT_OUTPUT_DIR:-screenshots}"
OUT="${DIR}/screenshots.json"
apify_run "neocraft~website-screenshot-pro" "$INPUT" "$CAP" "${INPUT_TIMEOUT_SECS:-600}" "$OUT"

OK=0; FAILED=0; FILES=()
while IFS=$'\t' read -r status src url device fmt; do
  if [ "$status" != "ok" ] || [ -z "$src" ] || [ "$src" = "null" ]; then
    FAILED=$((FAILED+1)); continue
  fi
  name="$(printf '%s' "$url" | sed -E 's#^https?://##; s#[^A-Za-z0-9._-]+#_#g; s#_+$##' | cut -c1-100)_${device}.${fmt}"
  if curl -sS --fail --retry 3 -o "${DIR}/${name}" "$src"; then
    OK=$((OK+1)); FILES+=("${DIR}/${name}")
  else
    FAILED=$((FAILED+1)); echo "::warning::Could not download ${src}"
  fi
done < <(jq -r --arg f "$FORMAT" '.[] | [(.status // "ok"), (.screenshotUrl // ""), (.url // "page"), (.device // "desktop"), (.format // $f)] | @tsv' "$OUT")

{
  echo "## Website screenshots"
  echo
  echo "| Page | Device | Status | Size | Link (Apify storage) |"
  echo "|---|---|---|---|---|"
  jq -r '.[] | "| \(.url // "") | \(.device // "") | \(.status // "")\(if .errorCode then " (" + .errorCode + ")" else "" end) | \(if .width then "\(.width)×\(.height)" else "" end) | \(if .screenshotUrl then "[open](" + .screenshotUrl + ")" else (.errorMessage // "" | gsub("\\|"; "/") | .[0:120]) end) |"' "$OUT"
  echo
  echo "${OK} file(s) saved to \`${DIR}/\`, ${FAILED} failed."
} | summary
footer "$CAP"

set_output count "$OK"
set_output failed-count "$FAILED"
set_output output-dir "$DIR"
set_output files "$(printf '%s\n' "${FILES[@]:-}")"
set_output screenshot-urls "$(jq -c '[.[] | select(.screenshotUrl) | {url, device, screenshotUrl}]' "$OUT")"

if [ "$FAILED" -gt 0 ] && [ "$(bool "${INPUT_FAIL_ON_ERROR:-}" false)" = "true" ]; then
  echo "::error::${FAILED} capture(s) failed"
  exit 1
fi
[ "$OK" -gt 0 ] || echo "::warning::No screenshot was produced"
echo "Saved ${OK} screenshot(s) to ${DIR}"
