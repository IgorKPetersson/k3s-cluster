#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

failures=0

record_failure() {
  printf '[FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}

check_command() {
  local command_name="$1"
  local guidance="$2"
  if command -v "${command_name}" >/dev/null 2>&1; then
    pass "Found ${command_name}: $(command -v "${command_name}")"
  else
    record_failure "${command_name} is missing. ${guidance}"
  fi
}

info "Checking prerequisites for cluster '${CLUSTER_NAME}'."

check_command docker "Install and start Docker Desktop."
check_command kubectl "Enable Kubernetes CLI tools in Docker Desktop or install kubectl."
check_command k3d "Run scripts/bootstrap-tools.sh."
check_command curl "Install curl and make it available to Bash."

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    docker_version="$(docker version --format '{{.Server.Version}}')"
    docker_cpus="$(docker info --format '{{.NCPU}}')"
    docker_memory="$(docker info --format '{{.MemTotal}}')"
    pass "Docker engine is available (version ${docker_version}, ${docker_cpus} CPUs)."
    if ((docker_memory < 6442450944)); then
      record_failure "Docker has less than 6 GiB of memory available. Increase Docker Desktop resources."
    else
      pass "Docker memory allocation is at least 6 GiB."
    fi
  else
    record_failure "Docker CLI exists, but the Docker engine is not reachable. Start Docker Desktop."
  fi
fi

if command -v k3d >/dev/null 2>&1; then
  installed_k3d="$(k3d version 2>/dev/null | awk '/k3d version/ { print $3; exit }')"
  if [[ "${installed_k3d}" == "${K3D_VERSION}" ]]; then
    pass "k3d version matches the pin (${K3D_VERSION})."
  else
    record_failure "k3d version is '${installed_k3d:-unknown}', expected '${K3D_VERSION}'. Run scripts/bootstrap-tools.sh."
  fi
fi

if command -v kubectl >/dev/null 2>&1; then
  kubectl_version="$(kubectl version --client 2>/dev/null | sed -nE 's/^Client Version: (v[0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n 1)"
  if [[ "${kubectl_version}" == "${KUBERNETES_MINOR}."* ]]; then
    pass "kubectl ${kubectl_version} matches Kubernetes minor ${KUBERNETES_MINOR}."
  else
    record_failure "kubectl version is '${kubectl_version:-unknown}', expected ${KUBERNETES_MINOR}.x."
  fi
fi

if command -v k3d >/dev/null 2>&1 && cluster_exists; then
  pass "Existing cluster '${CLUSTER_NAME}' owns the configured port check."
elif host_port_is_listening; then
  record_failure "Host port ${HOST_HTTP_PORT} is already listening. Free it or change HOST_HTTP_PORT in versions.env."
else
  pass "Host port ${HOST_HTTP_PORT} is available."
fi

if ((failures > 0)); then
  printf '[ERROR] Prerequisite check failed with %d problem(s).\n' "${failures}" >&2
  exit 1
fi

pass "All prerequisites are satisfied."
