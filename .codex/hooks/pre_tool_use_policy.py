"""Codex PreToolUse policy for destructive Git and cluster commands.

The hook reads one JSON event from stdin. Allowed commands produce no output.
Blocked commands produce the current Codex ``PreToolUse`` deny structure on
stdout. Invalid input fails closed.
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any


GIT = r"\bgit(?:\.exe)?[\"']?\s+"
GIT_GLOBAL_OPTIONS = (
    r"(?:(?:-[cC]\s+\S+|--(?:git-dir|work-tree)(?:=\S+|\s+\S+))\s+)*"
)
KUBECTL = r"\bkubectl(?:\.exe)?[\"']?\s+"
KUBECTL_GLOBAL_OPTIONS = (
    r"(?:(?:"
    r"--(?:kubeconfig|context|namespace|cluster|user|server|request-timeout)"
    r"(?:=\S+|\s+\S+)"
    r"|-[nsv]\s+\S+"
    r")\s+)*"
)
K3D = r"\bk3d(?:\.exe)?[\"']?\s+"
K3D_GLOBAL_OPTIONS = r"(?:(?:--(?:verbose|trace|timestamps))\s+)*"
DOCKER = r"\bdocker(?:\.exe)?[\"']?\s+"
DOCKER_GLOBAL_OPTIONS = (
    r"(?:(?:--context(?:=\S+|\s+\S+)|-H\s+\S+)\s+)*"
)
SHELL_TAIL = r"[^\r\n;&|]*"
HOMEWORK_CONTAINER = r"k3d-homework08-(?:server|agent|serverlb|tools)"


BLOCKED_RULES: tuple[tuple[str, re.Pattern[str]], ...] = (
    # Git history and reference protection retained from Homework 06.
    (
        "git reset can move a branch and discard local work",
        re.compile(GIT + GIT_GLOBAL_OPTIONS + r"reset\b", re.I),
    ),
    (
        "git rebase rewrites commits",
        re.compile(GIT + GIT_GLOBAL_OPTIONS + r"rebase\b", re.I),
    ),
    (
        "git commit --amend replaces the latest commit",
        re.compile(
            GIT + GIT_GLOBAL_OPTIONS + r"commit\b" + SHELL_TAIL + r"\s--amend\b",
            re.I,
        ),
    ),
    (
        "force-push or remote deletion can overwrite remote history",
        re.compile(
            GIT
            + GIT_GLOBAL_OPTIONS
            + r"push\b"
            + SHELL_TAIL
            + r"(?:^|\s)(?:"
            + r"-f\b|--force(?:-with-lease|-if-includes)?\b|--delete\b|\+\S+|:\S+"
            + r")",
            re.I,
        ),
    ),
    (
        "history filtering can rewrite many commits",
        re.compile(GIT + GIT_GLOBAL_OPTIONS + r"filter-(?:branch|repo)\b", re.I),
    ),
    (
        "git update-ref changes references directly",
        re.compile(GIT + GIT_GLOBAL_OPTIONS + r"update-ref\b", re.I),
    ),
    (
        "forced or deleting branch operations can remove history",
        re.compile(
            GIT
            + GIT_GLOBAL_OPTIONS
            + r"branch\b"
            + SHELL_TAIL
            + r"(?:^|\s)(?:-(?:f|M|d|D)\b|--(?:force|move|delete)\b)",
            re.I,
        ),
    ),
    (
        "git checkout -B or switch -C can replace an existing branch",
        re.compile(
            GIT + GIT_GLOBAL_OPTIONS + r"(?:checkout\s+-B|switch\s+-C)\b",
            re.I,
        ),
    ),
    (
        "forced or deleting tag operations can remove references",
        re.compile(
            GIT
            + GIT_GLOBAL_OPTIONS
            + r"tag\b"
            + SHELL_TAIL
            + r"(?:^|\s)(?:-[fd]\b|--(?:force|delete)\b)",
            re.I,
        ),
    ),
    (
        "git replace changes how existing history is interpreted",
        re.compile(GIT + GIT_GLOBAL_OPTIONS + r"replace\b", re.I),
    ),
    (
        "reflog deletion can remove recovery information",
        re.compile(
            GIT + GIT_GLOBAL_OPTIONS + r"reflog\s+(?:expire|delete)\b",
            re.I,
        ),
    ),
    (
        "git prune can permanently remove unreachable objects",
        re.compile(GIT + GIT_GLOBAL_OPTIONS + r"prune\b", re.I),
    ),
    # k3d lifecycle protection. The guarded destroy script is the approved path.
    (
        "direct k3d cluster deletion bypasses the guarded teardown script",
        re.compile(K3D + K3D_GLOBAL_OPTIONS + r"cluster\s+delete\b", re.I),
    ),
    (
        "stopping the Homework 08 cluster interrupts every cluster node",
        re.compile(
            K3D
            + K3D_GLOBAL_OPTIONS
            + r"cluster\s+stop\b"
            + SHELL_TAIL
            + r"\bhomework08\b",
            re.I,
        ),
    ),
    (
        "deleting or stopping a k3d node damages the cluster topology",
        re.compile(
            K3D + K3D_GLOBAL_OPTIONS + r"node\s+(?:delete|stop)\b",
            re.I,
        ),
    ),
    # Kubernetes cluster-wide and node-role protection.
    (
        "deleting a node, namespace, CRD, or persistent volume is cluster-wide",
        re.compile(
            KUBECTL
            + KUBECTL_GLOBAL_OPTIONS
            + r"delete\b"
            + SHELL_TAIL
            + r"(?:^|\s)(?:nodes?|namespaces?|ns|"
            + r"customresourcedefinitions?|crds?|persistentvolumes?|pv)(?:\s|/|$)",
            re.I,
        ),
    ),
    (
        "kubectl delete --all can remove an entire resource set",
        re.compile(
            KUBECTL
            + KUBECTL_GLOBAL_OPTIONS
            + r"delete\b"
            + SHELL_TAIL
            + r"(?:^|\s)--all(?:=true)?(?:\s|$)",
            re.I,
        ),
    ),
    (
        "kubectl delete all is broader than an individually named workload",
        re.compile(
            KUBECTL + KUBECTL_GLOBAL_OPTIONS + r"delete\s+all(?:\s|,|$)",
            re.I,
        ),
    ),
    (
        "kubectl drain disrupts workloads on a cluster node",
        re.compile(KUBECTL + KUBECTL_GLOBAL_OPTIONS + r"drain\b", re.I),
    ),
    (
        "direct node taint changes can remove control-plane isolation",
        re.compile(
            KUBECTL + KUBECTL_GLOBAL_OPTIONS + r"taint\s+nodes?\b",
            re.I,
        ),
    ),
    (
        "direct node role-label changes can violate exclusive roles",
        re.compile(
            KUBECTL
            + KUBECTL_GLOBAL_OPTIONS
            + r"label\s+nodes?\b"
            + SHELL_TAIL
            + r"node-role\.kubernetes\.io/(?:worker|control-plane)",
            re.I,
        ),
    ),
    (
        "direct node patching or editing can alter cluster role safeguards",
        re.compile(
            KUBECTL
            + KUBECTL_GLOBAL_OPTIONS
            + r"(?:patch|edit|replace)\s+nodes?\b",
            re.I,
        ),
    ),
    (
        "scaling a workload to zero causes a service outage",
        re.compile(
            KUBECTL
            + KUBECTL_GLOBAL_OPTIONS
            + r"scale\b"
            + SHELL_TAIL
            + r"--replicas(?:=|\s+)0(?:\s|$)",
            re.I,
        ),
    ),
    # Direct Docker protection for this cluster's containers and storage.
    (
        "direct Docker termination of a Homework 08 node bypasses cluster controls",
        re.compile(
            DOCKER
            + DOCKER_GLOBAL_OPTIONS
            + r"(?:container\s+)?(?:rm|kill|stop|restart)\b"
            + SHELL_TAIL
            + HOMEWORK_CONTAINER,
            re.I,
        ),
    ),
    (
        "removing the Homework 08 Docker network or volume damages cluster state",
        re.compile(
            DOCKER
            + DOCKER_GLOBAL_OPTIONS
            + r"(?:network|volume)\s+rm\b"
            + SHELL_TAIL
            + r"k3d-homework08",
            re.I,
        ),
    ),
)


def extract_command(payload: Any) -> str:
    """Return the Bash command from a Codex PreToolUse event."""
    if not isinstance(payload, dict):
        return ""
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return ""
    command = tool_input.get("command")
    return command if isinstance(command, str) else ""


def blocked_reason(command: str) -> str | None:
    """Return the first matching policy reason, or None when allowed."""
    for reason, pattern in BLOCKED_RULES:
        if pattern.search(command):
            return reason
    return None


def deny(reason: str) -> None:
    """Write the official Codex PreToolUse deny structure to stdout."""
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        f"Blocked by the Homework 08 safety policy: {reason}."
                    ),
                }
            }
        )
    )


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        deny("the hook received invalid JSON")
        return

    command = extract_command(payload)
    if not command:
        deny("the hook could not determine which Bash command would run")
        return

    reason = blocked_reason(command)
    if reason:
        deny(reason)
    # Exit 0 with no output to allow the command.


if __name__ == "__main__":
    main()
