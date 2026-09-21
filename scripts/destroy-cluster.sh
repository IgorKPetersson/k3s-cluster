#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_command k3d

if ! cluster_exists; then
  info "Cluster '${CLUSTER_NAME}' does not exist; nothing to remove."
  exit 0
fi

printf 'This will permanently delete only the k3d cluster named %s.\n' "${CLUSTER_NAME}"
read -r -p "Type ${CLUSTER_NAME} to continue: " confirmation
[[ "${confirmation}" == "${CLUSTER_NAME}" ]] || die "Confirmation did not match; cluster was not deleted."

k3d cluster delete "${CLUSTER_NAME}"
rm -f -- "${KUBECONFIG_FILE}" "${RENDERED_MANIFEST}"
pass "Cluster '${CLUSTER_NAME}' and its generated local state were removed."
