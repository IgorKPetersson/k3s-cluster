# Full-Cluster Agent Safety Hook

## Purpose

The Homework 08 safety net uses a project-level Codex `PreToolUse` hook to
inspect Bash commands before execution. It extends the Homework 06 Git policy
to protect the complete six-node k3s cluster.

The hook runs on the Windows laptop where the agent manages the cluster. A
single local policy therefore covers commands targeting any of the three
control-plane nodes, three workers, k3d lifecycle objects, or backing Docker
containers.

Configuration and implementation:

```text
.codex/
|-- hooks.json
`-- hooks/
    |-- pre_tool_use_policy.py
    |-- test_pre_tool_use_policy.py
    `-- demo_policy.py
```

The configuration follows the current
[official OpenAI Codex hooks documentation](https://developers.openai.com/codex/hooks/).
Allowed commands exit with no output. Blocked commands return the documented
`hookSpecificOutput` object with `permissionDecision: "deny"`.
Both configured commands resolve the policy from the Git repository root, so
the hook remains available when Codex starts from a repository subdirectory.

## Protected operations

| Area | Blocked command families | Reason |
|---|---|---|
| Git | reset, rebase, amend, force-push, reference deletion, history filtering, reflog deletion, and prune | Preserve local and remote recovery history. |
| k3d | direct cluster deletion, stopping `homework08`, and deleting or stopping nodes | Prevent loss or interruption of the full topology. |
| Kubernetes | deleting nodes/namespaces/CRDs/PVs, broad `--all` deletion, drain, protected node label/taint changes, node patch/edit/replace, and scaling to zero | Keep all six nodes, role separation, storage, and workloads available. |
| Docker | terminating named Homework 08 containers or deleting its network/volume | Prevent bypassing Kubernetes and k3d safeguards. |

The policy intentionally allows normal inspection, logs, manifest application,
rollout checks, ordinary commits, normal pushes, cluster creation/start, and the
controlled project scripts.

## Controlled destructive operation

Direct `k3d cluster delete` is denied. The supported teardown path is:

```bash
./scripts/destroy-cluster.sh
```

That script validates the fixed project cluster name and requires the operator
to type `homework08` before deletion. This is the assignment's controlled tool:
the agent cannot silently use the raw destructive command, while a human can
still perform intentional teardown through a narrow, reviewable interface.

## Activate the hook

1. Start Codex from the repository root.
2. Start a new session after adding or changing hook configuration.
3. Run `/hooks`.
4. Review and trust the project hook when its displayed hash and path match this
   repository.

Codex requires review because hooks execute local code. Changing the hook may
require it to be reviewed again.

## Test without executing dangerous commands

Run:

```bash
./scripts/test-safety-hook.sh
```

The unit tests pass command strings to the policy process but never execute
them. The demonstration prints `ALLOWED` or `BLOCKED` for representative
commands and also never executes the examples.

A safe live demonstration after trusting the hook is to ask the agent to run:

```bash
kubectl drain --help
```

The conservative policy blocks this because it classifies the command family,
including `--help`. If the hook were inactive, the fallback command would only
display help and would not modify the cluster.

## Fail-closed behavior

Malformed JSON, an invalid event structure, or a missing Bash command returns a
deny decision. This prevents a broken or incomplete event from silently
bypassing the policy.

## Limitations

This is a guardrail, not a complete shell sandbox. Deliberately obfuscated
commands, user-defined aliases, downloaded scripts, commands hidden inside
other programs, direct filesystem changes to `.git`, and specialized tool paths
that opt out of hooks are outside its guarantees. The cluster therefore also
uses role labels, control-plane taints, narrowly scoped scripts, ignored secret
state, and explicit operator confirmation.
