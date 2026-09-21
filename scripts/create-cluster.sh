#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

"${SCRIPT_DIR}/check-prerequisites.sh"
mkdir -p "${STATE_DIR}"

if cluster_exists; then
  info "Cluster '${CLUSTER_NAME}' already exists; reconciling labels and taints."
else
  info "Creating three k3s servers and three k3s agents."
  k3d cluster create "${CLUSTER_NAME}" \
    --servers 3 \
    --agents 3 \
    --image "${K3S_IMAGE}" \
    --port "${HOST_HTTP_PORT}:80@loadbalancer" \
    --k3s-arg "--node-taint=node-role.kubernetes.io/control-plane=true:NoSchedule@server:*" \
    --kubeconfig-update-default=false \
    --kubeconfig-switch-context=false \
    --timeout 300s \
    --wait
fi

temporary_kubeconfig="${KUBECONFIG_FILE}.tmp"
k3d kubeconfig get "${CLUSTER_NAME}" >"${temporary_kubeconfig}"

# k3d on Windows can emit host.docker.internal even though the API load
# balancer is published on the Windows loopback interface. Git Bash may resolve
# that hostname to a LAN address which cannot reach the published port.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    sed -i 's|https://host\.docker\.internal:|https://127.0.0.1:|' \
      "${temporary_kubeconfig}"
    ;;
esac

mv -- "${temporary_kubeconfig}" "${KUBECONFIG_FILE}"

info "Waiting for all six Kubernetes nodes to become Ready."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

for index in 0 1 2; do
  worker="k3d-${CLUSTER_NAME}-agent-${index}"
  server="k3d-${CLUSTER_NAME}-server-${index}"

  kubectl label node "${worker}" node-role.kubernetes.io/worker=true --overwrite
  kubectl label node "${server}" node-role.kubernetes.io/worker- >/dev/null 2>&1 || true
  kubectl taint node "${server}" \
    node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite
done

pass "Cluster '${CLUSTER_NAME}' is ready with enforced role separation."
kubectl get nodes -o wide
