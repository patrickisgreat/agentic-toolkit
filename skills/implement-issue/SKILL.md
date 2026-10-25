---
name: implement-issue
description: Implement a GitHub issue end to end the way the agentic-toolkit CI agent does - read the issue and any approved plan in docs/plans/, follow CLAUDE.md and docs/LEARNINGS.md, stay inside scope, write tests, commit on agent/issue-N, open a PR with "Closes #N" and the agent-generated label, and tick the acceptance criteria. Use when the user says "implement issue 42", "pick up this ticket", "do the agent-ready issue", or "/approve-plan was given, build it".
---

# Implement an issue

You are doing what the `agent-ready` label does in CI, but interactively. The contract is
the issue's acceptance criteria; the boundary is its Out of scope section.

## Steps

1. **Read the issue in full:**

   ```bash
   gh issue view <N> --json title,body,labels,comments
   ```

2. **Read the agent guide and the learnings.** `CLAUDE.md` at the repo root is the project's
   agent guide for every agent (`AGENTS.md` and `GEMINI.md` point at it). Read
   `docs/LEARNINGS.md` too. Treat both as binding.
3. **Look for an approved plan.** If the issue is `complexity:high`, find the matching plan in
   `docs/plans/` (most recent file whose title matches). It may live only on the branch
   `plan/issue-<N>`; check with `git fetch && git ls-tree origin/plan/issue-<N> docs/plans/`.
   Follow it. If no plan exists, implement directly from the issue.
4. **Reassess before building.** Issues are written ahead of time. Reconcile the Technical
   Notes against current code. If a referenced file, command, or pattern has changed, follow
   current reality and note the deviation in the PR body. If the divergence makes the intended
   approach wrong, stop and comment on the issue instead of building the wrong thing.
5. **Branch:** `git switch -c agent/issue-<N>` from the default branch.
6. **Implement** to the acceptance criteria exactly. Follow the patterns in the key files the
   issue names. Stay within In scope. Out of scope is a hard boundary even when the fix
   next door is tempting.
7. **Tests are mandatory.** Every behavior change ships with tests in the project's existing
   style. Read a sibling test first. If you cannot run the suite (missing toolchain, services,
   or network), trace each test by hand against the implementation. Never knowingly open a
   red PR. The project's CI on the PR is the real gate.
8. **Docs are part of done.** Update every documentation surface the acceptance criteria
   name. If the criteria name none and the change is user-visible, update the obvious one and
   say so in the PR.
9. **Commit** with Conventional Commits (`feat:`, `fix:`, `chore:`, ...) and push.
10. **Open the PR:**
    - Title matches the issue title.
    - Body starts with `Closes #<N>` on its own line. Keep the `#`; do not bold the keyword.
      A bare number or `**Closes:**` will not auto-close the issue.
    - Use `.github/PULL_REQUEST_TEMPLATE/agent-generated.md` if it exists; fill its
      Summary, Implementation Notes, Changes, and Testing sections honestly.
    - Label it `agent-generated`.

    ```bash
    gh pr create --title "<issue title>" --body-file /path/to/body.md --label agent-generated
    ```

11. **Update the issue's acceptance criteria.** Check off the boxes your implementation
    directly satisfies. Leave unchecked anything that requires manual testing, human review,
    or CI. Use `gh issue edit <N> --body-file` with the edited body.

## Hard rules

- Never merge. A human owns the merge decision.
- Never weaken test setup, lint config, or CI to make something pass.
- Never print, commit, or hardcode secrets.
- If blocked or genuinely uncertain, comment on the issue asking for clarification rather
  than guessing. A good issue rarely needs this; when it does, it is the right failure mode.
