# Homework 08: Six-Node k3s Cluster

This repository documents and automates a local, reusable k3s cluster for
Homework 08. The target topology contains three dedicated control-plane nodes
and three dedicated worker nodes. No application workload will be scheduled on
a control-plane node.

## Project status

Planning, reusable cluster automation, the Hello World deployment, and
live-cluster validation are complete. The full-cluster safety hook and final
screenshots remain to be completed.

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

## Quick start

Run the complete workflow from Git Bash:

```bash
./scripts/bootstrap-tools.sh
./scripts/check-prerequisites.sh
./scripts/lint.sh
./scripts/create-cluster.sh
./scripts/deploy-hello.sh
./scripts/verify.sh
```

The verified application is available at <http://localhost:8080>.

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
