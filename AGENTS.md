# Repository Working Agreement

All project files, code, comments, commit messages, and documentation must be
written in English.

## Session startup

Before changing the project:

1. Read `README.md`.
2. Read `docs/PLAN.md`.
3. Read `docs/HANDOFF.md`.
4. Inspect the Git status and preserve unrelated user changes.

## Continuity requirement

Update `docs/HANDOFF.md` after every meaningful task, not only at the end of the
entire assignment. A meaningful task includes planning, implementing a script or
manifest, changing the safety policy, running an important test, creating the
cluster, deploying the application, or capturing evidence.

The handoff must remain concise and must state:

- what was completed;
- files added or changed;
- commands or tests run and their outcomes;
- current environment or cluster state;
- unresolved problems or assumptions; and
- the next concrete task.

Update the relevant permanent documentation at the same time when behavior,
requirements, commands, architecture, or verification procedures change. Do
not use the handoff file as a substitute for maintaining the README and plan.

## Implementation principles

- Keep the setup reusable and intentionally simple.
- Automate cluster changes; do not rely on undocumented manual steps.
- Keep the three control-plane and three worker roles mutually exclusive.
- Do not commit kubeconfig data, tokens, credentials, or generated secrets.
- Run verification appropriate to each change before declaring the task done.
- Do not claim that a runtime check passed unless it was actually executed.
- Capture final screenshots only after a clean recreation and successful
  verification run.
