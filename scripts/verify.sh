#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_command kubectl
require_command curl
require_kubeconfig

failures=0

check_equal() {
  local description="$1"
  local actual="$2"
  local expected="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${description}: ${actual}"
  else
    printf '[FAIL] %s: expected %s, got %s\n' \
      "${description}" "${expected}" "${actual}" >&2
    failures=$((failures + 1))
  fi
}

info "Verifying six-node cluster topology."
node_count="$(kubectl get nodes -o name | count_nonempty_lines)"
control_plane_count="$(kubectl get nodes \
  --selector=node-role.kubernetes.io/control-plane \
  -o name | count_nonempty_lines)"
worker_count="$(kubectl get nodes \
  --selector=node-role.kubernetes.io/worker=true \
  -o name | count_nonempty_lines)"
dual_role_count="$(kubectl get nodes \
  --selector=node-role.kubernetes.io/control-plane,node-role.kubernetes.io/worker \
  -o name | count_nonempty_lines)"

check_equal "Total node count" "${node_count}" 6
check_equal "Control-plane node count" "${control_plane_count}" 3
check_equal "Worker node count" "${worker_count}" 3
check_equal "Nodes with both roles" "${dual_role_count}" 0

not_ready="$(kubectl get nodes \
  -o jsonpath='{range .items[*]}{.metadata.name}{"="}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}' \
  | awk -F= '$2 != "True" { print $1 }')"
if [[ -z "${not_ready}" ]]; then
  pass "All six nodes report Ready."
else
  printf '[FAIL] Nodes not Ready: %s\n' "${not_ready}" >&2
  failures=$((failures + 1))
fi

while IFS= read -r server_resource; do
  [[ -n "${server_resource}" ]] || continue
  server="${server_resource#node/}"
  if kubectl get node "${server}" \
    -o jsonpath='{range .spec.taints[*]}{.key}{"="}{.value}{":"}{.effect}{"\n"}{end}' \
    | grep -Fxq 'node-role.kubernetes.io/control-plane=true:NoSchedule'; then
    pass "${server} has the control-plane NoSchedule taint."
  else
    printf '[FAIL] %s is missing the control-plane NoSchedule taint.\n' "${server}" >&2
    failures=$((failures + 1))
  fi
done < <(kubectl get nodes --selector=node-role.kubernetes.io/control-plane -o name)

info "Verifying the Hello World workload."
pod_count="$(kubectl -n "${NAMESPACE}" get pods \
  --selector=app.kubernetes.io/name=homework08-hello \
  -o name | count_nonempty_lines)"
check_equal "Hello World pod count" "${pod_count}" 1

pod_name="$(kubectl -n "${NAMESPACE}" get pods \
  --selector=app.kubernetes.io/name=homework08-hello \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

if [[ -n "${pod_name}" ]]; then
  pod_phase="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" -o jsonpath='{.status.phase}')"
  pod_ready="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" \
    -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}')"
  pod_node="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" -o jsonpath='{.spec.nodeName}')"
  worker_label="$(kubectl get node "${pod_node}" \
    -o jsonpath='{.metadata.labels.node-role\.kubernetes\.io/worker}')"
  control_plane_label="$(kubectl get node "${pod_node}" \
    -o jsonpath='{.metadata.labels.node-role\.kubernetes\.io/control-plane}' 2>/dev/null || true)"

  check_equal "Hello World pod phase" "${pod_phase}" Running
  check_equal "Hello World pod readiness" "${pod_ready}" True
  check_equal "Pod worker label" "${worker_label}" true
  check_equal "Pod control-plane label" "${control_plane_label}" ""
  pass "Hello World pod is scheduled on worker node ${pod_node}."
else
  printf '[FAIL] No Hello World pod was found.\n' >&2
  failures=$((failures + 1))
fi

if kubectl -n "${NAMESPACE}" exec deployment/homework08-hello -- \
  wget -qO- http://homework08-hello | grep -Fq 'Homework 08'; then
  pass "The Service returns the expected page from inside the cluster."
else
  printf '[FAIL] The in-cluster Service check did not return the expected page.\n' >&2
  failures=$((failures + 1))
fi

host_response=""
for _ in $(seq 1 30); do
  if host_response="$(curl --fail --silent --show-error \
    --max-time 3 "http://localhost:${HOST_HTTP_PORT}" 2>/dev/null)"; then
    if grep -Fq 'Homework 08' <<<"${host_response}"; then
      break
    fi
  fi
  host_response=""
  sleep 2
done

if [[ -n "${host_response}" ]]; then
  pass "The page is reachable from the host at http://localhost:${HOST_HTTP_PORT}."
else
  printf '[FAIL] Host browser endpoint did not return the expected page.\n' >&2
  failures=$((failures + 1))
fi

printf '\nNode evidence:\n'
kubectl get nodes -o wide
printf '\nPod evidence:\n'
kubectl -n "${NAMESPACE}" get pods -o wide

if ((failures > 0)); then
  printf '\n[ERROR] Verification failed with %d problem(s).\n' "${failures}" >&2
  exit 1
fi

printf '\n[PASS] All cluster and application checks passed.\n'
