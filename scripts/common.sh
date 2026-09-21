#!/usr/bin/env bash

# This file is sourced by several entry points, so not every exported path is
# consumed when ShellCheck analyzes this file in isolation.
# shellcheck disable=SC2034

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

# shellcheck source=versions.env
source "${REPO_ROOT}/versions.env"

TOOLS_BIN="${REPO_ROOT}/.tools/bin"
STATE_DIR="${REPO_ROOT}/.state"
KUBECONFIG_FILE="${STATE_DIR}/kubeconfig.yaml"
RENDERED_MANIFEST="${STATE_DIR}/hello-world.rendered.yaml"

export PATH="${TOOLS_BIN}:${PATH}"
export KUBECONFIG="${KUBECONFIG_FILE}"

info() {
  printf '[INFO] %s\n' "$*"
}

pass() {
  printf '[PASS] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

cluster_exists() {
  k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -Fxq "${CLUSTER_NAME}"
}

require_kubeconfig() {
  [[ -s "${KUBECONFIG_FILE}" ]] || die \
    "Kubeconfig not found. Run scripts/create-cluster.sh first."
}

count_nonempty_lines() {
  awk 'NF { count++ } END { print count + 0 }'
}

host_port_is_listening() {
  if command -v netstat >/dev/null 2>&1; then
    netstat -an 2>/dev/null | grep -E "[.:]${HOST_HTTP_PORT}[[:space:]].*LISTEN" >/dev/null 2>&1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -E "[.:]${HOST_HTTP_PORT}[[:space:]]" >/dev/null 2>&1
  else
    return 1
  fi
}
