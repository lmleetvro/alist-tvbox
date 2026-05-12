#!/usr/bin/env bash
set -euo pipefail

readonly GH_PROXY_API_URL="https://api.akams.cn/github"
readonly GH_PROXY_TARGET_URL="https://github.com/har01d5/tvbox/raw/refs/heads/master/spiders_v2.json"

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
  printf '默认节点\tgh.llkk.cc\n'
}

build_proxy_url() {
  local host="$1"
  printf 'https://%s/%s\n' "$host" "$GH_PROXY_TARGET_URL"
}

sort_success_rows() {
  sort -t $'\t' -k4,4n -k5,5n -k2,2
}

main() {
  printf 'gh_proxy_bench skeleton\n'
}

if [[ "${GH_PROXY_BENCH_SOURCE_ONLY:-0}" != "1" ]]; then
  main "$@"
fi
