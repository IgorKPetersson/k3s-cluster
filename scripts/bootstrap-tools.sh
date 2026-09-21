#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

# shellcheck source=versions.env
source "${REPO_ROOT}/versions.env"

TOOLS_BIN="${REPO_ROOT}/.tools/bin"
DOWNLOAD_DIR="${REPO_ROOT}/.tools/downloads"
mkdir -p "${TOOLS_BIN}" "${DOWNLOAD_DIR}"

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    asset="k3d-windows-amd64.exe"
    checksum="${K3D_WINDOWS_AMD64_SHA256}"
    destination="${TOOLS_BIN}/k3d.exe"
    ;;
  Linux*)
    [[ "$(uname -m)" == "x86_64" ]] || {
      printf '[ERROR] Only Linux x86_64 and Windows x86_64 are currently supported.\n' >&2
      exit 1
    }
    asset="k3d-linux-amd64"
    checksum="${K3D_LINUX_AMD64_SHA256}"
    destination="${TOOLS_BIN}/k3d"
    ;;
  *)
    printf '[ERROR] Unsupported operating system: %s\n' "$(uname -s)" >&2
    exit 1
    ;;
esac

if [[ -x "${destination}" ]]; then
  installed_version="$("${destination}" version 2>/dev/null | awk '/k3d version/ { print $3; exit }')"
  if [[ "${installed_version}" == "${K3D_VERSION}" ]]; then
    printf '[PASS] k3d %s is already installed in .tools/bin.\n' "${K3D_VERSION}"
    exit 0
  fi
fi

command -v curl >/dev/null 2>&1 || {
  printf '[ERROR] curl is required to download k3d.\n' >&2
  exit 1
}
command -v sha256sum >/dev/null 2>&1 || {
  printf '[ERROR] sha256sum is required to verify the k3d download.\n' >&2
  exit 1
}

download="${DOWNLOAD_DIR}/${asset}"
url="https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/${asset}"

printf '[INFO] Downloading k3d %s from its official GitHub release.\n' "${K3D_VERSION}"
curl --fail --location --retry 3 --output "${download}" "${url}"
printf '%s *%s\n' "${checksum}" "${download}" | sha256sum --check --status || {
  printf '[ERROR] The downloaded k3d checksum did not match versions.env.\n' >&2
  exit 1
}

mv -- "${download}" "${destination}"
chmod +x "${destination}"

actual_version="$("${destination}" version | awk '/k3d version/ { print $3; exit }')"
[[ "${actual_version}" == "${K3D_VERSION}" ]] || {
  printf '[ERROR] Installed k3d version is %s, expected %s.\n' \
    "${actual_version}" "${K3D_VERSION}" >&2
  exit 1
}

printf '[PASS] Installed and verified k3d %s in .tools/bin.\n' "${K3D_VERSION}"
