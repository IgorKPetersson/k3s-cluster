#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_command k3d
require_command docker

cluster_network="k3d-${CLUSTER_NAME}"
network_is_orphaned=false
if [[ "$(docker network inspect "${cluster_network}" \
  --format '{{ index .Labels "app" }}:{{ len .Containers }}' 2>/dev/null || true)" == "k3d:0" ]]; then
  network_is_orphaned=true
fi

if ! cluster_exists && [[ "${network_is_orphaned}" == false ]]; then
  rm -f -- "${KUBECONFIG_FILE}" "${RENDERED_MANIFEST}"
  info "Cluster '${CLUSTER_NAME}' and its generated Docker network do not exist."
  exit 0
fi

printf 'This will permanently delete only the k3d cluster named %s.\n' "${CLUSTER_NAME}"
read -r -p "Type ${CLUSTER_NAME} to continue: " confirmation
[[ "${confirmation}" == "${CLUSTER_NAME}" ]] || die "Confirmation did not match; cluster was not deleted."

if cluster_exists; then
  k3d cluster delete "${CLUSTER_NAME}"
fi

if [[ "$(docker network inspect "${cluster_network}" \
  --format '{{ index .Labels "app" }}:{{ len .Containers }}' 2>/dev/null || true)" == "k3d:0" ]]; then
  docker network rm "${cluster_network}" >/dev/null
  info "Removed the empty k3d network '${cluster_network}'."
fi

rm -f -- "${KUBECONFIG_FILE}" "${RENDERED_MANIFEST}"
pass "Cluster '${CLUSTER_NAME}' and its generated local state were removed."
