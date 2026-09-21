#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_command docker

docker info >/dev/null 2>&1 || die "Docker Desktop must be running to execute the quality tools."

docker_repository_root="${REPO_ROOT}"
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    require_command cygpath
    docker_repository_root="$(cygpath -m "${REPO_ROOT}")"
    # Prevent MSYS from rewriting Linux paths intended for containers.
    export MSYS_NO_PATHCONV=1
    ;;
esac

info "Running ShellCheck ${SHELLCHECK_IMAGE} against the Bash automation."
docker run --rm \
  --volume "${docker_repository_root}:/work:ro" \
  --workdir /work \
  "${SHELLCHECK_IMAGE}" \
  -x \
  scripts/*.sh
pass "ShellCheck passed."

info "Validating the rendered manifest with ${KUBECONFORM_IMAGE}."
sed "s|__HELLO_IMAGE__|${HELLO_IMAGE}|g" \
  "${REPO_ROOT}/manifests/hello-world.yaml" \
  | docker run --rm --interactive "${KUBECONFORM_IMAGE}" \
      -strict \
      -summary \
      -kubernetes-version "${KUBERNETES_MINOR#v}.0"
pass "kubeconform passed."
