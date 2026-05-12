#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export GH_PROXY_BENCH_SOURCE_ONLY=1
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/gh_proxy_bench.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [[ "$expected" != "$actual" ]]; then
    printf 'ASSERT FAIL: %s\nexpected: [%s]\nactual:   [%s]\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

test_build_proxy_url() {
  local actual
  actual="$(build_proxy_url "gh.llkk.cc")"
  assert_eq \
    "https://gh.llkk.cc/https://github.com/har01d5/tvbox/raw/refs/heads/master/spiders_v2.json" \
    "$actual" \
    "build_proxy_url should prepend host to fixed target"
}

test_normalize_label() {
  assert_eq "默认节点" "$(normalize_label "gh.llkk.cc" "random-tag")" "default host should override tag"
  assert_eq "公益贡献" "$(normalize_label "edge.example" "donate")" "donate tag should map to 公益贡献"
  assert_eq "search" "$(normalize_label "edge.example" "search")" "other tags should be preserved"
}

test_fallback_nodes() {
  local actual
  actual="$(fallback_nodes)"
  assert_eq $'默认节点\tgh.llkk.cc' "$actual" "fallback_nodes should expose the built-in fallback host"
}

test_sort_success_rows() {
  local input expected actual
  input=$'公益贡献\thk.example\t200\t0.220\t0.440\thttps://hk.example/example\n默认节点\tgh.llkk.cc\t200\t0.110\t0.330\thttps://gh.llkk.cc/example\n搜索引擎\tsearch.example\t200\t0.110\t0.350\thttps://search.example/example'
  expected=$'默认节点\tgh.llkk.cc\t200\t0.110\t0.330\thttps://gh.llkk.cc/example\n搜索引擎\tsearch.example\t200\t0.110\t0.350\thttps://search.example/example\n公益贡献\thk.example\t200\t0.220\t0.440\thttps://hk.example/example'
  actual="$(sort_success_rows <<<"$input")"
  assert_eq "$expected" "$actual" "sort_success_rows should order by starttransfer then total then host"
}

test_parse_nodes_with_jq_or_python() {
  local payload actual expected
  payload='{"code":200,"data":[{"url":"https://gh.llkk.cc/https://github.com/example","tag":"donate"},{"url":"https://edgeone.gh-proxy.org/https://github.com/example","tag":"search"},{"url":"https://gh.llkk.cc/https://github.com/example","tag":"duplicate"}]}'
  expected=$'默认节点\tgh.llkk.cc\nsearch\tedgeone.gh-proxy.org'
  actual="$(parse_nodes_from_payload "$payload")"
  assert_eq "$expected" "$actual" "parse_nodes_from_payload should extract unique hosts and normalized labels"
}

test_parse_nodes_rejects_bad_payload() {
  local actual
  actual="$(parse_nodes_from_payload '{"code":500,"data":[]}' || true)"
  assert_eq "" "$actual" "parse_nodes_from_payload should emit nothing for unusable payloads"
}

test_build_proxy_url
test_normalize_label
test_fallback_nodes
test_sort_success_rows
test_parse_nodes_with_jq_or_python
test_parse_nodes_rejects_bad_payload

printf 'gh_proxy_bench tests: PASS\n'
