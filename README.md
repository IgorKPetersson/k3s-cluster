# Homework 08: Six-Node k3s Cluster

This repository documents and automates a local, reusable k3s cluster for
Homework 08. The target topology contains three dedicated control-plane nodes
and three dedicated worker nodes. No application workload will be scheduled on
a control-plane node.

## Project status

Homework 08 is complete. The repository contains reusable cluster automation,
the Hello World deployment, a tested full-cluster safety hook, a verified clean
recreation, and final evidence screenshots.

Current progress, verification results, environment state, and the exact next
task are recorded in [docs/HANDOFF.md](docs/HANDOFF.md). Every meaningful task
updates that file so work can resume safely if a session ends unexpectedly.

## Chosen approach

The cluster will run with [k3d](https://k3d.io/), which creates k3s nodes as
Docker containers. This keeps the six-node setup reproducible on a Windows 11
laptop without requiring six full virtual machines.

- Three k3s server nodes provide the control plane and embedded etcd quorum.
- Three k3s agent nodes provide worker capacity.
- Control-plane nodes are tainted to prevent application scheduling.
- Worker nodes receive an explicit worker-role label.
- The Hello World workload uses a worker-only node selector.
- k3d's load balancer publishes the application to the Windows host so it can
  be opened in a normal laptop browser.

See [docs/PLAN.md](docs/PLAN.md) for the complete architecture,
implementation sequence, verification criteria, safety policy, and evidence
checklist.

See [docs/SETUP.md](docs/SETUP.md) for the executable setup, deployment,
verification, inspection, and teardown workflow.

See [docs/SAFETY.md](docs/SAFETY.md) for the protected command families,
controlled teardown path, hook activation, safe demonstration, and limitations.

## Quick start

Run the complete workflow from Git Bash:

```bash
./scripts/bootstrap-tools.sh
./scripts/check-prerequisites.sh
./scripts/lint.sh
./scripts/test-safety-hook.sh
./scripts/create-cluster.sh
./scripts/deploy-hello.sh
./scripts/verify.sh
```

The verified application is available at <http://localhost:8080>.

From Windows PowerShell, regenerate the evidence screenshots after a successful
verification run:

```powershell
.\scripts\capture-evidence.ps1
```

## Final evidence

The five required assessment screenshots were captured manually from Git Bash
and the laptop browser. The safety-hook image is additional evidence.

| Screenshot | What it proves |
|---|---|
| [Cluster creation](screenshots/01-cluster-creation.png) | The reusable setup script passes its prerequisites, reconciles the cluster, waits for all six nodes, and enforces role separation. |
| [Six-node runtime](screenshots/02-six-node-runtime.png) | The three server and three agent containers are running. |
| [Role separation](screenshots/03-role-separation.png) | Kubernetes reports three Ready workers and three Ready control-plane/etcd nodes. |
| [Hello World browser page](screenshots/04-hello-world-browser.png) | The application is reachable from the Windows host on port 8080. |
| [Running pod](screenshots/05-running-pod.png) | The Ready Hello World pod is placed on a dedicated worker. |
| [Safety hook](screenshots/06-safety-hook.png) | Representative destructive commands are blocked without being executed. |

## Planned repository structure

```text
.
|-- .codex/                  # Agent safety-hook configuration and policy
|-- docs/                    # Architecture, instructions, and evidence guide
|-- manifests/               # Hello World Kubernetes resources
|-- scripts/                 # Reusable cluster lifecycle and verification scripts
|-- screenshots/             # Selected assessment evidence
|-- versions.env             # Pinned tools, images, names, and host port
|-- README.md
`-- LICENSE
```

The scripts and manifests will be the source of truth. The cluster will not be
built through undocumented manual commands.
