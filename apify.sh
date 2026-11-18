#!/usr/bin/env bash
# Shared helpers: start an Apify Actor run, poll it until it finishes, download its dataset.
# Requires: bash, curl, jq (all preinstalled on GitHub-hosted runners).
# Maintained by Xiaoli, an AI assistant, for Neocraft. MIT license.

APIFY_API="${APIFY_API_BASE_URL:-https://api.apify.com}/v2"

log()  { echo "[apify] $*" >&2; }
fail() { echo "::error::$*" >&2; exit 1; }

# set_output NAME VALUE  (multi-line safe)
set_output() {
  local name="$1" value="$2" delim
  delim="EOF_$(date +%s%N)_$RANDOM"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    { echo "${name}<<${delim}"; printf '%s\n' "$value"; echo "${delim}"; } >> "$GITHUB_OUTPUT"
  else
    log "output ${name}=${value}"
  fi
}

summary() { if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat >> "$GITHUB_STEP_SUMMARY"; else cat >&2; fi; }

# split_list "a, b\nc"  -> JSON array ["a","b","c"]  (comma or newline separated, blanks dropped)
split_list() {
  printf '%s' "${1:-}" | tr ',' '\n' | jq -R -s -c 'split("\n") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))'
}

# bool "true"/"false"/"" -> true|false (default given as $2)
bool() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    true|yes|1|on) echo true ;;
    false|no|0|off) echo false ;;
    *) echo "${2:-false}" ;;
  esac
}

check_prereqs() {
  command -v curl >/dev/null || fail "curl is required"
  command -v jq   >/dev/null || fail "jq is required"
  [ -n "${APIFY_TOKEN:-}" ] || fail "Input 'apify-token' is empty. Add your Apify API token as a repository secret (e.g. APIFY_TOKEN) and pass it with: apify-token: \${{ secrets.APIFY_TOKEN }}"
  [ "${GITHUB_ACTIONS:-}" = "true" ] && echo "::add-mask::${APIFY_TOKEN}"
  return 0
}

# merge_extra BASE_JSON EXTRA_JSON -> merged JSON (EXTRA wins). Fails on invalid EXTRA.
merge_extra() {
  local base="$1" extra="${2:-}"
  [ -z "$extra" ] && { echo "$base"; return; }
  echo "$extra" | jq -e 'type == "object"' >/dev/null 2>&1 || fail "Input 'extra-input' must be a JSON object"
  jq -c -n --argjson a "$base" --argjson b "$extra" '$a + $b'
}

api() { # api METHOD PATH [DATA]
  local method="$1" path="$2" data="${3:-}"
  local args=(-sS --retry 3 --retry-delay 3 --max-time 120 -X "$method"
    -H "Authorization: Bearer ${APIFY_TOKEN}" -H "Content-Type: application/json" -w '\n%{http_code}')
  [ -n "$data" ] && args+=(--data-binary "$data")
  curl "${args[@]}" "${APIFY_API}${path}"
}

# apify_run ACTOR_ID INPUT_JSON MAX_CHARGE_USD TIMEOUT_SECS OUT_FILE
# Sets globals RUN_ID RUN_STATUS RUN_URL RUN_COST ITEM_COUNT
apify_run() {
  local actor="$1" input="$2" cap="$3" timeout="$4" out="$5" resp code body q
  q="maxTotalChargeUsd=${cap}"
  [ -n "$timeout" ] && [ "$timeout" != "0" ] && q="${q}&timeout=${timeout}"
  log "Starting ${actor} (spend cap \$${cap})"
  resp="$(api POST "/acts/${actor}/runs?${q}" "$input")" || fail "Could not reach the Apify API"
  code="$(tail -n1 <<<"$resp")"; body="$(sed '$d' <<<"$resp")"
  if [ "$code" != "201" ]; then
    fail "Apify refused to start ${actor} (HTTP ${code}): $(jq -r '.error.message // .' <<<"$body" 2>/dev/null | head -c 500)"
  fi
  RUN_ID="$(jq -r '.data.id' <<<"$body")"
  local dataset; dataset="$(jq -r '.data.defaultDatasetId' <<<"$body")"
  RUN_URL="https://console.apify.com/view/runs/${RUN_ID}"
  log "Run ${RUN_ID} started: ${RUN_URL}"

  RUN_STATUS="RUNNING"
  local deadline=$(( $(date +%s) + ${timeout:-3600} + 120 ))
  while :; do
    resp="$(api GET "/actor-runs/${RUN_ID}?waitForFinish=60")" || { sleep 5; continue; }
    code="$(tail -n1 <<<"$resp")"; body="$(sed '$d' <<<"$resp")"
    [ "$code" = "200" ] || { log "poll HTTP ${code}, retrying"; sleep 5; continue; }
    RUN_STATUS="$(jq -r '.data.status' <<<"$body")"
    case "$RUN_STATUS" in
      SUCCEEDED|FAILED|ABORTED|TIMED-OUT|TIMED_OUT) break ;;
    esac
    [ "$(date +%s)" -gt "$deadline" ] && { log "giving up polling"; break; }
    log "status ${RUN_STATUS}..."
  done
  log "Run finished: ${RUN_STATUS}"

  resp="$(api GET "/datasets/${dataset}/items?clean=true&format=json")" || fail "Could not download results"
  code="$(tail -n1 <<<"$resp")"; body="$(sed '$d' <<<"$resp")"
  [ "$code" = "200" ] || fail "Could not download results (HTTP ${code})"
  mkdir -p "$(dirname "$out")"
  printf '%s' "$body" > "$out"
  ITEM_COUNT="$(jq 'length' "$out")"
  log "${ITEM_COUNT} result item(s) saved to ${out}"

  set_output run-id "$RUN_ID"
  set_output run-url "$RUN_URL"
  set_output run-status "$RUN_STATUS"
  set_output results-file "$out"
  set_output item-count "$ITEM_COUNT"

  if [ "$RUN_STATUS" != "SUCCEEDED" ]; then
    echo "::warning::Apify run ${RUN_ID} ended with status ${RUN_STATUS} (it may have hit the spend cap or timeout). Partial results were saved. Details: ${RUN_URL}"
  fi
}

footer() {
  summary <<EOF

<sub>Apify run: [${RUN_ID}](${RUN_URL}) · status ${RUN_STATUS} · spend cap \$${1} · billed to your own Apify account (pay per event).</sub>
EOF
}
