# Project Handoff

Last updated: 2026-09-21

## Current milestone

Stage 3 is complete. The project-level Codex safety hook is restored as
`.codex/hooks.json`, its Git and cluster policy is tested, and the live six-node
cluster and Hello World application still pass all verification. Stage 4 is the
final clean recreation and evidence capture.

## Completed work

- Cloned the empty public `IgorKPetersson/k3s-cluster` repository into the local
  workspace.
- Created the initial project README.
- Created the detailed Homework 08 implementation plan.
- Selected k3d as the local k3s platform.
- Defined the six-node topology: three k3s servers and three k3s agents.
- Defined role enforcement through control-plane taints, explicit worker labels,
  and a worker-only node selector for the Hello World workload.
- Defined browser access through the k3d load balancer on
  `http://localhost:8080`.
- Defined the intended Bash automation, verification checks, safety-hook scope,
  screenshot set, completion criteria, and major risks.
- Added this continuity process and the repository working agreement.
- Added Windows-safe Git attributes and ignore rules.
- Pinned k3d `v5.9.0`, k3s `v1.36.4+k3s1`, the Hello World image, and quality
  tool images in `versions.env`.
- Implemented a checksum-verified, project-local k3d bootstrap.
- Implemented prerequisite, create, deploy, verify, lint, and guarded teardown
  scripts.
- Implemented the Namespace, ConfigMap, Deployment, Service, and Traefik
  Ingress for Hello World.
- Added complete setup and operation instructions.
- Created the live cluster and deployed the application.
- Corrected a Windows-specific generated kubeconfig endpoint from
  `host.docker.internal` to the API port on `127.0.0.1`.
- Added the project-level Codex `PreToolUse` hook configuration and a fail-closed
  Python policy for destructive Git, k3d, kubectl, and Docker commands.
- Added unit, protocol, configuration, subdirectory-launch, and non-execution
  tests plus a safe policy demonstration.
- Added the safety guide and linked the hook checks from the main workflow.
- Restored the temporarily disabled configuration to `.codex/hooks.json`.
- Made both platform commands resolve the hook policy from the Git root so the
  configuration also works when Codex starts in a repository subdirectory.

## Files currently added

- `AGENTS.md`
- `.gitattributes`
- `.gitignore`
- `README.md`
- `docs/PLAN.md`
- `docs/HANDOFF.md`
- `docs/SETUP.md`
- `manifests/hello-world.yaml`
- `scripts/bootstrap-tools.sh`
- `scripts/check-prerequisites.sh`
- `scripts/common.sh`
- `scripts/create-cluster.sh`
- `scripts/deploy-hello.sh`
- `scripts/destroy-cluster.sh`
- `scripts/lint.sh`
- `scripts/verify.sh`
- `.codex/hooks.json`
- `.codex/hooks/pre_tool_use_policy.py`
- `.codex/hooks/test_pre_tool_use_policy.py`
- `.codex/hooks/demo_policy.py`
- `docs/SAFETY.md`
- `scripts/test-safety-hook.sh`
- `versions.env`

The Task 1 through Task 3 source files are committed on `main` and published to
`origin/main`. Project-local binaries, kubeconfig data, and rendered manifests
remain ignored and were not included.

## Environment observations

- Host: Windows 11.
- Docker CLI: installed; client version reported as `29.7.2`.
- Docker engine: running; version `29.7.2`, 32 CPUs, and approximately 31 GiB
  available to Docker Desktop.
- kubectl: installed; client version `v1.36.1`.
- Python: installed; Python 3.12 executable detected.
- k3d: project-local `v5.9.0`, checksum verified.
- k3s: `v1.36.4+k3s1` on all six nodes.
- ShellCheck: pinned container `koalaman/shellcheck:v0.11.0`.
- kubeconform: pinned container `ghcr.io/yannh/kubeconform:v0.8.0`.
- Helm, kind, and Vagrant: not installed and not required by the current plan.
- Generated tools and kubeconfig state exist under `.tools/` and `.state/` and
  are excluded from Git.

## Current cluster state

- Cluster name: `homework08`.
- Three Ready server nodes with `control-plane,etcd` roles.
- Three Ready agent nodes with the explicit `worker` role.
- No node has both roles.
- All server nodes have the expected control-plane `NoSchedule` taint.
- The Hello World pod is Running and Ready on `k3d-homework08-agent-1`.
- The internal Service returns the expected page.
- `http://localhost:8080` returns the expected page from the Windows host.
- k3d also runs load-balancer and utility containers; these are not Kubernetes
  nodes, and `kubectl get nodes` returns exactly the required six nodes.

## Verification performed

- Confirmed the remote Homework 08 repository is public and empty before the
  initial clone.
- Confirmed the local clone succeeded.
- Ran `git diff --check` after creating the plan; no whitespace errors were
  reported.
- Read and reviewed the complete reference Homework 06 repository, including
  its README, Codex hook configuration, Git safety policy, demonstration script,
  and unit tests.
- Bash syntax validation passed for every script.
- The prerequisite check first failed only for missing k3d, then passed after
  the checksum-verified bootstrap.
- ShellCheck passed for every Bash script.
- kubeconform validated all five rendered Kubernetes resources with zero
  invalid resources, errors, or skips.
- Cluster creation completed successfully after the Windows kubeconfig endpoint
  correction.
- The create and deploy scripts were rerun successfully; existing resources
  were reconciled or reported unchanged.
- `scripts/verify.sh` passed all topology, exclusivity, readiness, taint, pod,
  placement, in-cluster HTTP, and host HTTP checks.
- The guarded teardown script rejected an incorrect confirmation; the cluster
  and web endpoint remained available.
- `git diff --check` reported no whitespace errors before the final handoff
  update.
- Compared the configuration and deny response with the current official OpenAI
  Codex hooks documentation.
- `python -m py_compile` passed for all three hook Python files.
- All 10 safety-hook unit, protocol, and configuration tests passed, including
  configured execution from the `docs/` subdirectory.
- `scripts/test-safety-hook.sh` passed in Git Bash and the demonstration
  classified its examples without executing them.
- `scripts/lint.sh` passed ShellCheck and validated all five Kubernetes
  resources with kubeconform.
- `scripts/verify.sh` again passed all cluster, role, pod, Service, and host HTTP
  checks after the hook work.

## Decisions and assumptions

- Prefer k3d over six full virtual machines to keep the assignment lightweight
  and reproducible on one laptop.
- Use Bash scripts and plain Kubernetes YAML rather than Ansible, Helm,
  Terraform, or Rancher.
- Pin tested k3d, k3s, application, ShellCheck, and kubeconform versions in
  `versions.env`.
- Use Python standard-library `unittest` for the hook policy.
- Run ShellCheck and kubeconform from pinned containers instead of requiring
  global installations.
- Extend the Homework 06 `PreToolUse` concept to Git, kubectl, k3d, and direct
  Docker operations against the homework cluster.
- Provide a validated, confirmation-based destroy script as the controlled path
  for cluster teardown.
- Resolve repository-local hook commands from the Git root because Codex can be
  started from a subdirectory.

## Open items

- Perform one final teardown and clean recreation after the safety hook is
  complete.
- Capture final evidence after a clean recreation.
- Add the project license and decide whether a lightweight GitHub Actions
  quality workflow is worthwhile.
- Keep future commits and pushes explicit, reviewable, and free of generated
  kubeconfig data or project-local binaries.
- In a new Codex session, use `/hooks` to review and trust the restored project
  hook; trust is stored against the exact hook-definition hash.

## Next concrete task

Run Stage 4, the final clean-recreation and evidence workflow:

1. Review and trust the restored hook with `/hooks` in a new Codex session.
2. Use the guarded teardown script with explicit operator confirmation.
3. Recreate the cluster only from the documented scripts and manifests.
4. Run lint, safety-hook tests, deployment, and complete verification.
5. Capture the planned screenshots only after every check passes.
6. Update the README and this handoff with the final evidence paths and results.
