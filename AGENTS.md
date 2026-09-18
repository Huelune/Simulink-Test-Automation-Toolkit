# Project Working Agreement

- After completing requested project changes and reasonable local verification, commit the task-scoped changes automatically unless the user explicitly asks not to commit.
- Never include unrelated user changes in an automatic commit.
- If MATLAB or another required runtime is unavailable locally, record that limitation and still commit the completed implementation after available static checks pass.
- Every new or materially extended feature must emit project-standard `st_log` lifecycle diagnostics, including start/end checkpoints around long-running APIs and WARN/ERROR context for degraded or failed paths.
- Before changing branches or continuing MATLAB runtime work, read `docs/codex-handoff.md`. It is the agent-only source of truth for active branch roles, superseded experiments, unverified runtime assumptions, and required handoff evidence.

## Working alongside other sessions

Several Claude sessions run against this repository at once, and by default they
all share one working directory. One directory means one branch and one set of
files: a `git checkout` in one session moves the ground under the others, and a
file edited by two sessions loses whichever write lands first.

- Before editing a file, run `git fetch` and check whether the branch moved.
  Another session may have already made the change you are about to make.
- A session that does not need MATLAB (documentation, slides, analysis) should
  work in its own worktree. Ask for one explicitly: "worktree 만들어서 작업해줘".
- A session that runs MATLAB stays in the original working directory. MATLAB
  keeps its state per directory (`runtime_target.mat`, `result/`), so a worktree
  would need its own `st_setup` and target selection, and would write a separate
  `result/` tree.
- Only one session at a time should run MATLAB against this repository.
