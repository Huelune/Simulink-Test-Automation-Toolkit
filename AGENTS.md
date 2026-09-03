# Project Working Agreement

- After completing requested project changes and reasonable local verification, commit the task-scoped changes automatically unless the user explicitly asks not to commit.
- Never include unrelated user changes in an automatic commit.
- If MATLAB or another required runtime is unavailable locally, record that limitation and still commit the completed implementation after available static checks pass.
- Every new or materially extended feature must emit project-standard `st_log` lifecycle diagnostics, including start/end checkpoints around long-running APIs and WARN/ERROR context for degraded or failed paths.
- Before changing branches or continuing MATLAB runtime work, read `docs/codex-handoff.md`. It is the agent-only source of truth for active branch roles, superseded experiments, unverified runtime assumptions, and required handoff evidence.
