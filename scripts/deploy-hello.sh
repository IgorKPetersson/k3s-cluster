#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_command kubectl
require_kubeconfig
mkdir -p "${STATE_DIR}"

sed "s|__HELLO_IMAGE__|${HELLO_IMAGE}|g" \
  "${REPO_ROOT}/manifests/hello-world.yaml" >"${RENDERED_MANIFEST}"

if grep -q '__[A-Z_]*__' "${RENDERED_MANIFEST}"; then
  die "The rendered manifest still contains an unresolved placeholder."
fi

info "Applying the Hello World resources."
kubectl apply -f "${RENDERED_MANIFEST}"

info "Waiting for the Hello World deployment."
kubectl -n "${NAMESPACE}" rollout status deployment/homework08-hello --timeout=300s
kubectl -n "${NAMESPACE}" wait \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/name=homework08-hello \
  --timeout=300s

pass "Hello World is deployed."
kubectl -n "${NAMESPACE}" get pods -o wide
printf 'Browser URL: http://localhost:%s\n' "${HOST_HTTP_PORT}"
