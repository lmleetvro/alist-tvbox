#!/usr/bin/env bash
set -euo pipefail

readonly GH_PROXY_API_URL="https://api.akams.cn/github"
readonly GH_PROXY_TARGET_URL="https://github.com/har01d5/tvbox/raw/refs/heads/master/spiders_v2.json"

script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

result_file_path() {
  printf '%s/gh_proxy_bench_result.json\n' "$(script_dir)"
}

normalize_label() {
  local host="$1"
  local tag="${2:-}"
  if [[ "$host" == "gh.llkk.cc" ]]; then
    printf '默认节点\n'
  elif [[ "$tag" == "donate" ]]; then
    printf '公益贡献\n'
  else
    printf '%s\n' "${tag:-未命名节点}"
  fi
}

fallback_nodes() {
  printf '%s\n' \
    $'默认节点\tgh.llkk.cc' \
    $'备用节点\tgh-proxy.org' \
    $'备用节点\thk.gh-proxy.org' \
    $'备用节点\tcdn.gh-proxy.org' \
    $'备用节点\tedgeone.gh-proxy.org' \
    $'备用节点\tgh.felicity.ac.cn'
}

build_proxy_url() {
  local host="$1"
  printf 'https://%s/%s\n' "$host" "$GH_PROXY_TARGET_URL"
}

sort_success_rows() {
  sort -t $'\t' -k4,4n -k5,5n -k2,2
}

parse_nodes_with_jq() {
  local payload="$1"
  jq -r '
    if (.code == 200 and (.data | type == "array")) then
      .data[]
      | select(.url? and (.url | type == "string"))
      | [.url, (.tag // "")]
      | @tsv
    else
      empty
    end
  ' <<<"$payload" | while IFS=$'\t' read -r raw_url raw_tag; do
    local host
    host="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).hostname or "")' "$raw_url")"
    [[ -n "$host" ]] || continue
    printf '%s\t%s\n' "$(normalize_label "$host" "$raw_tag")" "$host"
  done | awk -F '\t' '!seen[$2]++'
}

parse_nodes_with_python() {
  local payload="$1"
  python3 - "$payload" <<'PY'
import json
import sys
from urllib.parse import urlparse

payload = json.loads(sys.argv[1])
if payload.get("code") != 200 or not isinstance(payload.get("data"), list):
    raise SystemExit(0)

seen = set()
for item in payload["data"]:
    raw_url = item.get("url")
    if not isinstance(raw_url, str):
        continue
    host = urlparse(raw_url).hostname or ""
    if not host or host in seen:
        continue
    seen.add(host)
    tag = item.get("tag") or ""
    print(f"{tag}\t{host}")
PY
}

parse_nodes_from_payload() {
  local payload="$1"
  local rows=""
  if command -v jq >/dev/null 2>&1; then
    rows="$(parse_nodes_with_jq "$payload")"
  else
    rows="$(
      parse_nodes_with_python "$payload" | while IFS=$'\t' read -r raw_tag host; do
        printf '%s\t%s\n' "$(normalize_label "$host" "$raw_tag")" "$host"
      done
    )"
  fi

  if [[ -n "$rows" ]]; then
    printf '%s\n' "$rows" | awk 'NF > 0'
  fi
}

discover_nodes() {
  local payload rows
  if payload="$(curl --location --silent --show-error --fail "$GH_PROXY_API_URL")"; then
    rows="$(parse_nodes_from_payload "$payload" || true)"
    if [[ -n "$rows" ]]; then
      printf '%s\n' "$rows"
      return 0
    fi
  fi

  fallback_nodes
}

format_success_row() {
  local label="$1"
  local host="$2"
  local metrics="$3"
  local status ttfb total url
  IFS=$'\t' read -r status ttfb total <<<"$metrics"
  url="$(build_proxy_url "$host")"
  printf '%s\t%s\t%s\t%.3f\t%.3f\t%s\n' "$label" "$host" "$status" "$ttfb" "$total" "$url"
}

format_failure_row() {
  local host="$1"
  local reason="$2"
  printf '%s\t%s\n' "$host" "$reason"
}

benchmark_host() {
  local label="$1"
  local host="$2"
  local url curl_output curl_status status
  url="$(build_proxy_url "$host")"

  set +e
  curl_output="$(
    curl \
      --location \
      --silent \
      --show-error \
      --output /dev/null \
      --connect-timeout 8 \
      --max-time 30 \
      --write-out $'%{http_code}\t%{time_starttransfer}\t%{time_total}' \
      "$url" 2>&1
  )"
  curl_status=$?
  set -e

  if [[ $curl_status -ne 0 ]]; then
    format_failure_row "$host" "curl_exit_${curl_status}"
    return 1
  fi

  IFS=$'\t' read -r status _ <<<"$curl_output"
  if [[ ! "$status" =~ ^[0-9]{3}$ ]] || (( status >= 400 )) || (( status < 200 )); then
    format_failure_row "$host" "http_${status}"
    return 1
  fi

  format_success_row "$label" "$host" "$curl_output"
}

print_success_table() {
  local rows="$1"
  printf 'Success Nodes\n'
  printf '%-12s %-28s %-6s %-10s %-10s %s\n' "Label" "Host" "HTTP" "TTFB(s)" "Total(s)" "URL"
  while IFS=$'\t' read -r label host status ttfb total url; do
    [[ -n "${host:-}" ]] || continue
    printf '%-12s %-28s %-6s %-10s %-10s %s\n' "$label" "$host" "$status" "$ttfb" "$total" "$url"
  done <<<"$rows"
}

print_failure_table() {
  local rows="$1"
  [[ -n "$rows" ]] || return 0
  printf '\nFailed Nodes\n'
  printf '%-28s %s\n' "Host" "Reason"
  while IFS=$'\t' read -r host reason; do
    [[ -n "${host:-}" ]] || continue
    printf '%-28s %s\n' "$host" "$reason"
  done <<<"$rows"
}

render_json_report() {
  local generated_at="$1"
  local success_rows="$2"
  local failure_rows="$3"

  python3 - "$generated_at" "$GH_PROXY_TARGET_URL" "$GH_PROXY_API_URL" "$success_rows" "$failure_rows" <<'PY'
import json
import sys

generated_at, target_url, discovery_api, success_rows, failure_rows = sys.argv[1:6]

success_nodes = []
for line in success_rows.splitlines():
    if not line.strip():
        continue
    label, host, status, ttfb, total, benchmark_url = line.split("\t")
    success_nodes.append({
        "label": label,
        "host": host,
        "http_status": int(status),
        "ttfb_seconds": float(ttfb),
        "total_seconds": float(total),
        "benchmark_url": benchmark_url,
    })

failed_nodes = []
for line in failure_rows.splitlines():
    if not line.strip():
        continue
    host, reason = line.split("\t", 1)
    failed_nodes.append({
        "host": host,
        "reason": reason,
    })

print(json.dumps({
    "generated_at": generated_at,
    "target_url": target_url,
    "discovery_api": discovery_api,
    "success_nodes": success_nodes,
    "failed_nodes": failed_nodes,
}, ensure_ascii=False, indent=2))
PY
}

write_json_report() {
  local generated_at="$1"
  local success_rows="$2"
  local failure_rows="$3"
  local output_path tmp_file

  output_path="$(result_file_path)"
  tmp_file="$(mktemp "${output_path}.tmp.XXXXXX")"
  render_json_report "$generated_at" "$success_rows" "$failure_rows" >"$tmp_file"
  mv "$tmp_file" "$output_path"
}

main() {
  local discovered row success_rows="" failure_rows="" generated_at
  discovered="$(discover_nodes)"

  while IFS=$'\t' read -r label host; do
    [[ -n "${host:-}" ]] || continue
    if row="$(benchmark_host "$label" "$host")"; then
      success_rows+="${row}"$'\n'
    else
      failure_rows+="${row}"$'\n'
    fi
  done <<<"$discovered"

  success_rows="$(printf '%s' "$success_rows" | awk 'NF > 0')"
  failure_rows="$(printf '%s' "$failure_rows" | awk 'NF > 0')"

  if [[ -n "$success_rows" ]]; then
    success_rows="$(printf '%s\n' "$success_rows" | sort_success_rows)"
    print_success_table "$success_rows"
  else
    printf 'No successful proxy nodes.\n'
  fi

  print_failure_table "$failure_rows"

  generated_at="$(date -Iseconds)"
  write_json_report "$generated_at" "$success_rows" "$failure_rows"
}

if [[ "${GH_PROXY_BENCH_SOURCE_ONLY:-0}" != "1" ]]; then
  main "$@"
fi
