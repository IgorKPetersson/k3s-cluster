from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("pre_tool_use_policy.py")
REPO_ROOT = SCRIPT.parents[2]
HOOKS_CONFIG = REPO_ROOT / ".codex" / "hooks.json"
SPEC = importlib.util.spec_from_file_location("pre_tool_use_policy", SCRIPT)
assert SPEC and SPEC.loader
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)


class PolicyRuleTests(unittest.TestCase):
    def test_allows_read_only_and_expected_workflow_commands(self) -> None:
        commands = (
            "git status",
            "git diff --cached",
            "git log --oneline -5",
            "git commit -m 'normal commit'",
            "git push origin main",
            "kubectl get nodes -o wide",
            "kubectl -n homework08 get pods -o wide",
            "kubectl describe node k3d-homework08-agent-0",
            "kubectl apply -f manifests/hello-world.yaml",
            "kubectl rollout status deployment/homework08-hello",
            "kubectl logs deployment/homework08-hello",
            "k3d cluster list",
            "k3d cluster create temporary-test",
            "k3d cluster start homework08",
            "docker ps",
            "docker logs k3d-homework08-server-0",
            "docker inspect k3d-homework08-agent-0",
            "./scripts/create-cluster.sh",
            "./scripts/destroy-cluster.sh",
            "python .codex/hooks/demo_policy.py",
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNone(POLICY.blocked_reason(command))

    def test_blocks_git_history_rewriting_commands(self) -> None:
        commands = (
            "git reset --hard HEAD~1",
            "git rebase -i HEAD~3",
            "git commit --amend --no-edit",
            "git push origin main --force",
            "git push -f origin main",
            "git push --force-with-lease origin main",
            "git.exe push --force-if-includes origin main",
            "git push origin +main:main",
            "git push origin :main",
            "git push origin --delete main",
            "git filter-branch -- --all",
            "git filter-repo --path secret.txt --invert-paths",
            "git update-ref refs/heads/main HEAD~1",
            "git branch -f main HEAD~1",
            "git branch -D old-branch",
            "git checkout -B main HEAD~1",
            "git switch -C main HEAD~1",
            "git tag -f v1.0 HEAD~1",
            "git tag --delete v1.0",
            "git replace HEAD HEAD~1",
            "git reflog expire --expire=now --all",
            "git prune",
            "echo first; git rebase main",
            "git -C ../other reset --hard",
            "git --git-dir=.git rebase main",
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNotNone(POLICY.blocked_reason(command))

    def test_blocks_destructive_cluster_commands(self) -> None:
        commands = (
            "k3d cluster delete homework08",
            ".tools/bin/k3d.exe cluster delete homework08",
            '"C:/tools/k3d.exe" cluster delete homework08',
            "k3d cluster stop homework08",
            "k3d node delete k3d-homework08-agent-0",
            "k3d node stop k3d-homework08-server-0",
            "kubectl delete node k3d-homework08-agent-0",
            "kubectl delete nodes k3d-homework08-agent-0",
            "kubectl --context k3d-homework08 delete namespace homework08",
            "kubectl --context=k3d-homework08 delete ns homework08",
            "kubectl -n homework08 delete pods --all",
            "kubectl delete all --all -n homework08",
            "kubectl drain k3d-homework08-agent-0",
            "kubectl taint nodes k3d-homework08-server-0 node-role.kubernetes.io/control-plane-",
            "kubectl label node k3d-homework08-server-0 node-role.kubernetes.io/worker=true",
            "kubectl patch node k3d-homework08-server-0 --type merge -p '{}'",
            "kubectl edit nodes k3d-homework08-server-0",
            "kubectl replace node k3d-homework08-server-0 -f node.yaml",
            "kubectl scale deployment homework08-hello --replicas=0",
            "docker stop k3d-homework08-server-0",
            "docker container rm -f k3d-homework08-agent-2",
            "docker kill k3d-homework08-serverlb",
            "docker restart k3d-homework08-tools",
            "docker network rm k3d-homework08",
            "docker volume rm k3d-homework08-images",
            "echo first && kubectl drain k3d-homework08-agent-1",
        )
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNotNone(POLICY.blocked_reason(command))


class HookProtocolTests(unittest.TestCase):
    def run_hook(self, command: str) -> subprocess.CompletedProcess[str]:
        payload = json.dumps(
            {
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash",
                "tool_input": {"command": command},
            }
        )
        return subprocess.run(
            [sys.executable, str(SCRIPT)],
            input=payload,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_allowed_command_exits_zero_without_output(self) -> None:
        result = self.run_hook("kubectl get nodes")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")

    def test_blocked_command_returns_current_codex_deny_shape(self) -> None:
        result = self.run_hook("kubectl drain k3d-homework08-agent-0")
        output = json.loads(result.stdout)
        decision = output["hookSpecificOutput"]
        self.assertEqual(result.returncode, 0)
        self.assertEqual(decision["hookEventName"], "PreToolUse")
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertIn("kubectl drain", decision["permissionDecisionReason"])

    def test_invalid_json_fails_closed(self) -> None:
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            input="not-json",
            text=True,
            capture_output=True,
            check=False,
        )
        decision = json.loads(result.stdout)["hookSpecificOutput"]
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertIn("invalid JSON", decision["permissionDecisionReason"])

    def test_missing_command_fails_closed(self) -> None:
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            input=json.dumps({"hook_event_name": "PreToolUse", "tool_input": {}}),
            text=True,
            capture_output=True,
            check=False,
        )
        decision = json.loads(result.stdout)["hookSpecificOutput"]
        self.assertEqual(decision["permissionDecision"], "deny")

    def test_policy_never_executes_the_command_string(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "should-not-exist.txt"
            command = (
                "kubectl drain k3d-homework08-agent-0; "
                f'python -c "open(r\'{marker}\', \'w\').write(\'unsafe\')"'
            )
            result = self.run_hook(command)
            self.assertIn('"permissionDecision": "deny"', result.stdout)
            self.assertFalse(marker.exists())


class HookConfigurationTests(unittest.TestCase):
    def test_configuration_matches_bash_pre_tool_use(self) -> None:
        config = json.loads(HOOKS_CONFIG.read_text(encoding="utf-8"))
        matcher_group = config["hooks"]["PreToolUse"][0]
        handler = matcher_group["hooks"][0]

        self.assertEqual(matcher_group["matcher"], "^Bash$")
        self.assertEqual(handler["type"], "command")
        self.assertEqual(handler["timeout"], 10)
        self.assertIn("pre_tool_use_policy.py", handler["command"])
        self.assertIn("pre_tool_use_policy.py", handler["commandWindows"])
        self.assertIn("git", handler["commandWindows"])
        self.assertIn("rev-parse", handler["commandWindows"])

    def run_configured_hook(
        self, command: str, cwd: Path = REPO_ROOT
    ) -> subprocess.CompletedProcess[str]:
        config = json.loads(HOOKS_CONFIG.read_text(encoding="utf-8"))
        handler = config["hooks"]["PreToolUse"][0]["hooks"][0]
        hook_command = (
            handler["commandWindows"] if sys.platform == "win32" else handler["command"]
        )
        payload = json.dumps(
            {
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash",
                "tool_input": {"command": command},
            }
        )
        return subprocess.run(
            hook_command,
            cwd=cwd,
            input=payload,
            text=True,
            capture_output=True,
            shell=True,
            check=False,
        )

    def test_configured_hook_allows_and_denies(self) -> None:
        allowed = self.run_configured_hook("kubectl get nodes")
        blocked = self.run_configured_hook("k3d cluster delete homework08")
        blocked_from_subdirectory = self.run_configured_hook(
            "kubectl drain k3d-homework08-agent-0", REPO_ROOT / "docs"
        )

        self.assertEqual(allowed.returncode, 0, allowed.stderr)
        self.assertEqual(allowed.stdout, "")
        self.assertEqual(blocked.returncode, 0, blocked.stderr)
        decision = json.loads(blocked.stdout)["hookSpecificOutput"]
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertEqual(
            blocked_from_subdirectory.returncode,
            0,
            blocked_from_subdirectory.stderr,
        )
        subdirectory_decision = json.loads(
            blocked_from_subdirectory.stdout
        )["hookSpecificOutput"]
        self.assertEqual(subdirectory_decision["permissionDecision"], "deny")


if __name__ == "__main__":
    unittest.main()
