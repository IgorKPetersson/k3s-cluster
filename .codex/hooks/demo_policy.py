"""Display policy decisions without executing any example command."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


POLICY_PATH = Path(__file__).with_name("pre_tool_use_policy.py")
SPEC = importlib.util.spec_from_file_location("pre_tool_use_policy", POLICY_PATH)
assert SPEC and SPEC.loader
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)

EXAMPLES = (
    "git status",
    "git push origin main",
    "kubectl get nodes -o wide",
    "kubectl apply -f manifests/hello-world.yaml",
    "k3d cluster list",
    "./scripts/destroy-cluster.sh",
    "git reset --hard HEAD~1",
    "git push --force origin main",
    "kubectl delete namespace homework08",
    "kubectl drain k3d-homework08-agent-0",
    "k3d cluster delete homework08",
    "docker stop k3d-homework08-server-0",
)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print("Homework 08 safety policy dry run (no commands are executed)\n")
    for command in EXAMPLES:
        reason = POLICY.blocked_reason(command)
        verdict = "BLOCKED" if reason else "ALLOWED"
        print(f"{verdict:7}  {command}")
        if reason:
            print(f"         - {reason}")


if __name__ == "__main__":
    main()
