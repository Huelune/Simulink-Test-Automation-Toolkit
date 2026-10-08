# Project Working Agreement

- After completing requested project changes and reasonable local verification, commit the task-scoped changes automatically unless the user explicitly asks not to commit.
- Never include unrelated user changes in an automatic commit.
- If MATLAB or another required runtime is unavailable locally, record that limitation and still commit the completed implementation after available static checks pass.
- Every new or materially extended feature must emit project-standard `st_log` lifecycle diagnostics, including start/end checkpoints around long-running APIs and WARN/ERROR context for degraded or failed paths.
- Follow `docs/ai/commit-convention.md` when creating or proposing commits: one logical change per commit, Conventional Commits format, and a commit plan presented first when several are needed.
- Before changing branches or continuing MATLAB runtime work, read `docs/ai/codex-handoff.md`. It is the agent-only source of truth for active branch roles, superseded experiments, unverified runtime assumptions, and required handoff evidence.

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

## Asking the user to run MATLAB

MATLAB runs in a separate clone inside the model project, out of the agent's
reach. Anything the user must run there goes through `todo.md`, and its output
must fit on one screen, because the user answers with a single screenshot.

- Put the request in the repository-root `todo.md` as a numbered section, then
  commit and push it to `develop`. Each section states why it is run, a MATLAB
  block to paste as is, what to check, and what to send back. In chat, point to
  the section instead of pasting the code. Delete a section once its result is
  handled.
- Design the output for one screen: `clc` first, warnings off and restored,
  one line per item, passing items as a count, detail only for failures, at most
  about 40 lines of 120 columns. Write long text (full error reports) to a file
  under `tempdir` and print only its path.
- When something can fail, print why it failed on the same screen. A table of
  names alone forces a second run.
- Build paths from `st_project_root()`, never from the current folder. `st_setup`
  does not add `tests` to the path, so pass test files to `runtests` by full path
  (`fullfile(st_project_root(), 'tests', 'unit', '<name>.m')`); by name alone it
  stops with "테스트 스위트를 만들 수 없습니다".
