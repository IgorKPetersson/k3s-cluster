#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

command -v python >/dev/null 2>&1 || {
  printf '[ERROR] Python 3 is required to test the safety hook.\n' >&2
  exit 1
}

printf '[INFO] Running safety-hook unit and protocol tests.\n'
python "${REPO_ROOT}/.codex/hooks/test_pre_tool_use_policy.py" -v
printf '\n[INFO] Running the no-execution policy demonstration.\n'
python "${REPO_ROOT}/.codex/hooks/demo_policy.py"
printf '\n[PASS] Safety-hook tests and demonstration completed.\n'
