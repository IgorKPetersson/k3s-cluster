# Homework 08 Implementation Plan

## 1. Objective

Create, secure, verify, and document a reusable k3s cluster with exactly six
Kubernetes nodes:

- three dedicated control-plane nodes;
- three dedicated worker nodes; and
- no node carrying both roles.

The finished cluster must run a Hello World web workload, expose it to a browser
on the Windows 11 host, and demonstrate an agent safety net based on the
Homework 06 hook concept.

## 2. Constraints and assumptions

- Host operating system: Windows 11.
- Working tools: Visual Studio Code, Bash, and Git.
- Docker Desktop uses the WSL 2 backend and is available to the Bash shell.
- The solution must be reproducible through scripts and Kubernetes manifests.
- Screenshots are evidence only; they are not a substitute for source-controlled
  automation or verification output.
- Generated kubeconfig data, credentials, and other secrets must not be
  committed.

### Work continuity

`docs/HANDOFF.md` is the recovery point for interrupted work. It will be updated
after every meaningful task with completed changes, verification results,
current state, blockers, and the next concrete task. `AGENTS.md` makes this a
repository-level requirement for future work sessions. Permanent instructions
in this plan and the README must also be updated whenever implementation
behavior changes.

## 3. Architecture decision

### Selected platform: k3d

k3d runs k3s nodes in Docker containers. It is a good fit for this assignment
because it supports multiple k3s server and agent nodes, runs locally on the
Windows laptop, and makes teardown and recreation deterministic.

The implementation pins the tested k3d and k3s versions in `versions.env`
instead of silently depending on whatever version happens to be latest.

### Logical topology

```text
Windows 11 browser
        |
        | http://localhost:8080
        v
k3d load balancer / published port 8080 -> cluster port 80
        |
        v
Traefik Ingress -> Hello World Service -> Hello World Pod
                                             |
                                             | worker node selector
                                             v
                           +------------------------------------+
                           | worker-0 | worker-1 | worker-2     |
                           +------------------------------------+

        Kubernetes API / embedded etcd quorum
                           +------------------------------------+
                           | server-0 | server-1 | server-2     |
                           | control-plane + etcd only           |
                           +------------------------------------+
```

### Role separation

The server nodes will carry only the Kubernetes control-plane/etcd roles. Each
server node will receive a `NoSchedule` control-plane taint so ordinary
application pods cannot run there.

The three agent nodes will receive the explicit label:

```text
node-role.kubernetes.io/worker=true
```

The Hello World workload will use that label as a `nodeSelector`. Role
separation will therefore be visible in node metadata and enforced by the
scheduler rather than existing only in documentation.

Kubernetes system components managed by k3s may still be visible in the system
namespace. They are part of the control plane or cluster networking and do not
give a server node the worker role.

## 4. Automation

The cluster will not be assembled through undocumented manual commands. The
following Bash entry points are implemented:

| File | Responsibility |
|---|---|
| `scripts/check-prerequisites.sh` | Check Docker, k3d, kubectl, ports, and required versions before making changes. |
| `scripts/bootstrap-tools.sh` | Download the pinned k3d binary locally and verify its SHA-256 checksum. |
| `scripts/lint.sh` | Run pinned ShellCheck and kubeconform containers. |
| `scripts/create-cluster.sh` | Create three servers and three agents, map the browser port, apply labels/taints, and wait for readiness. |
| `scripts/deploy-hello.sh` | Apply the version-controlled Hello World manifest and wait for a successful rollout. |
| `scripts/verify.sh` | Prove node count, exclusive roles, readiness, worker-only placement, service health, and HTTP reachability. |
| `scripts/destroy-cluster.sh` | Remove only the named homework cluster after an explicit confirmation. |

Scripts use strict Bash settings, stable resource names, bounded waits, and
clear error messages. The create and deploy workflow has been verified as
idempotent.

## 5. Hello World design

The manifest contains:

- a ConfigMap with a small, identifiable English HTML page;
- a one-replica Deployment that creates the required running pod;
- a ClusterIP Service; and
- an Ingress routed through the k3s-provided Traefik controller.

The Deployment includes readiness and liveness probes plus a worker-only node
selector. The application image uses a fixed version rather than a floating
`latest` tag.

The planned browser path is:

```text
http://localhost:8080
```

k3d publishes laptop port `8080` to port `80` on its load balancer. Traefik
receives that request inside the cluster, matches the Ingress, and forwards it
through the Service to the Hello World pod on one of the three workers. This
avoids relying on an internal container IP that the Windows browser cannot
reach directly.

## 6. Full-cluster agent safety net

The Homework 06 project-level `PreToolUse` design will be reused and expanded.
The hook runs on the laptop, where the agent issues cluster-management commands,
so one policy can protect operations targeting every node.

The planned policy will:

- retain protection against Git history rewriting and destructive reference
  changes;
- deny deletion of the k3d homework cluster;
- deny high-impact Kubernetes operations such as deleting nodes, namespaces, or
  all resources;
- deny commands that drain or remove multiple cluster nodes without the user in
  the loop;
- deny direct Docker removal or termination of the named k3d node containers;
- fail closed if the hook input cannot be parsed; and
- allow read-only inspection, normal Git commits/pushes, manifest application,
  rollout checks, logs, and other commands required for the assignment.

Automated tests will cover allowed commands, blocked commands, malformed hook
input, and the configured Windows command path. A demonstration script will
classify sample commands without executing them.

The hook is an additional safety layer, not a replacement for careful scripts,
least privilege, backups, or explicit operator review.

## 7. Implementation sequence

1. Record prerequisites and pin compatible tool/image versions.
2. Implement and test the cluster lifecycle scripts.
3. Create the six-node cluster and enforce exclusive roles.
4. Implement the Hello World resources and deploy them.
5. Implement and test the full-cluster safety hook.
6. Run the automated verification and save its text output.
7. Capture the required screenshots using the evidence checklist.
8. Complete the README with exact setup, usage, teardown, troubleshooting, and
   browser-access instructions.
9. Recreate the cluster from a clean state to prove that the documented process
   is reusable.

## 8. Verification plan

The verification script and the final documentation will provide evidence for
all of the following:

| Requirement | Verification |
|---|---|
| Six nodes exist | `kubectl get nodes` returns exactly six nodes. |
| Three control-plane nodes | Exactly three nodes carry the control-plane role. |
| Three workers | Exactly three nodes carry the explicit worker label. |
| No dual-role nodes | No node has both the control-plane and worker labels. |
| All nodes work | All six nodes report `Ready`. |
| Control-plane isolation | Server nodes have the expected `NoSchedule` taint. |
| Pod works | The Hello World pod is `Running` and ready. |
| Pod uses a worker | The pod's assigned node has the worker label and no control-plane role. |
| Service works | An in-cluster request receives the expected page content. |
| Laptop access works | A host-side request to `http://localhost:8080` receives the expected page content. |
| Safety hook works | Tests pass and representative destructive commands receive a deny decision. |

## 9. Screenshot and evidence plan

The final submission will include at least these five required screenshots:

1. **Cluster creation:** successful completion of the reusable creation script.
2. **Six-node runtime:** the k3d/Docker node inventory showing three servers and
   three agents.
3. **Kubernetes role separation:** six Ready nodes with the three control-plane
   roles and three explicit worker roles visible.
4. **Hello World webpage:** the page open at `http://localhost:8080` in the
   laptop's browser.
5. **Running pod:** `kubectl get pods -o wide` showing the ready pod placed on a
   worker node.

An additional safety-hook test or deny screenshot may be included because it
directly supports the Homework 06 portion.

Screenshots will be stored under `screenshots/` with numbered, descriptive file
names. The README will explain what each screenshot proves.

## 10. Completion criteria

The project is complete only when:

- a clean machine with the documented prerequisites can run the supplied
  workflow without undocumented setup steps;
- all automated checks pass;
- the cluster has three exclusive control-plane nodes and three exclusive worker
  nodes;
- the Hello World page is reachable from the Windows browser;
- the pod is demonstrably running on a worker;
- the safety hook blocks its documented dangerous operations;
- the required screenshots are present and referenced; and
- the English README explains creation, verification, browser access, safety,
  teardown, and known limitations.

## 11. Main risks and mitigations

| Risk | Mitigation |
|---|---|
| Six containers exceed laptop resources | Use lightweight k3s nodes, document Docker resource requirements, and run prerequisite checks. |
| Host port 8080 is already occupied | Detect the conflict before cluster creation and allow an explicit port override. |
| Workload lands on a server node | Combine a control-plane taint with a mandatory worker node selector and verify placement. |
| Version drift breaks recreation | Pin and document tested tool and image versions. |
| A destructive command removes cluster state | Use narrowly targeted scripts, explicit teardown confirmation, and the project safety hook. |
| Screenshot evidence becomes inconsistent with code | Capture evidence only after the final clean recreation and verification run. |
