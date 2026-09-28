# Setup and Operation

## Prerequisites

- Windows 11
- Docker Desktop using Linux containers
- Git for Windows, including Git Bash
- kubectl `v1.36.x`
- curl and sha256sum, both included with Git for Windows
- at least 6 GiB of memory available to Docker Desktop

k3d does not require a system-wide installation. The bootstrap script downloads
the pinned release from the official k3d GitHub repository, verifies its SHA-256
checksum, and places it in the gitignored `.tools/bin` directory.

## Create the cluster

Open Git Bash in the repository root and run:

```bash
./scripts/bootstrap-tools.sh
./scripts/check-prerequisites.sh
./scripts/create-cluster.sh
```

The creation script builds three k3s server nodes and three k3s agent nodes. It
stores the generated kubeconfig under `.state/` instead of modifying the user's
default Kubernetes configuration. On Windows, it also normalizes k3d's generated
API endpoint to the loopback address so Git Bash reaches the port published by
Docker Desktop reliably.

## Run static quality checks

```bash
./scripts/lint.sh
```

The lint script runs the pinned ShellCheck and kubeconform container images.
This validates the Bash automation and rendered Kubernetes manifest without
requiring either utility to be installed globally.

## Deploy and verify Hello World

```bash
./scripts/deploy-hello.sh
./scripts/verify.sh
```

After verification succeeds, open:

```text
http://localhost:8080
```

The request travels from the Windows host to the published k3d load-balancer
port, through the Traefik Ingress and Kubernetes Service, and finally to the pod
on a dedicated worker node.

## Inspect the cluster manually

The scripts automatically select the project-local kubeconfig. For an
interactive shell, export it before running kubectl directly:

```bash
export KUBECONFIG="$PWD/.state/kubeconfig.yaml"
kubectl get nodes -o wide
kubectl -n homework08 get pods -o wide
```

## Capture final evidence

After `scripts/verify.sh` passes, open Windows PowerShell in the repository root
and run:

```powershell
.\scripts\capture-evidence.ps1
```

The script queries the live cluster and uses an installed Microsoft Edge or
Google Chrome browser in headless mode. It writes six PNG files to
`screenshots/`; temporary HTML evidence pages remain ignored under `artifacts/`.
Do not treat screenshots captured before a clean recreation and successful
verification as final evidence.

## Delete the cluster

```bash
./scripts/destroy-cluster.sh
```

The teardown script operates only on the cluster name pinned in `versions.env`
and requires the operator to type that exact name before deletion. It also
removes an empty, k3d-labeled network with the exact generated cluster name so
an interrupted prior teardown cannot contaminate a later clean recreation.

## Configuration

Pinned tool, Kubernetes, application-image, cluster-name, namespace, and host
port values live in `versions.env`. Change them there rather than editing each
script. Re-run the prerequisite and verification scripts after any change.
