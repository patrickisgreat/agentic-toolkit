---
name: address-pr-feedback
description: Make exactly the change a reviewer requested on an open pull request and push it to the PR branch, without refactoring or widening scope. This is the interactive form of the "@agent <instruction>" PR comment loop. Use when the user says "address the review comments on PR 57", "the reviewer asked for X, do it", "fix what CI flagged on my PR", or pastes review feedback.
---

# Address PR feedback

A reviewer asked for a specific change. Make that change, nothing more, so the PR updates
and CI re-runs. The PR's scope was set by its issue; feedback does not expand it.

## Inputs

- A PR number and the request. If the request is not in the conversation, read it from the
  PR:

  ```bash
  gh pr view <PR> --json title,body,comments,reviews,headRefName,closingIssuesReferences
  ```

  Treat the most recent `@agent` or `@claude` comment, or the most recent
  changes-requested review, as the instruction.

## Steps

1. **Check out the head branch** (`gh pr checkout <PR>`) and pull so you are at the tip.
2. **Read the diff** so you know what the PR does and what the request refers to:

   ```bash
   gh pr diff <PR>
   ```

3. **Read `CLAUDE.md` and `docs/LEARNINGS.md`** so the fix matches project conventions.
4. **Make exactly the requested change.** Do not refactor unrelated code. Do not expand the
   PR's scope. If the request reveals a second problem, mention it in a PR comment rather
   than fixing it silently.
5. **Update or add tests** for any behavior you change. Run them if the toolchain is
   available; otherwise trace them by hand. Never push a knowingly red change.
6. **Commit** on the current branch with a Conventional Commit message that names what the
   reviewer asked for, and **push** so the PR updates and CI re-runs.
7. **Reply on the PR** in one or two lines: what changed, and the commit hash. If any part of
   the request was not done, say which and why.

## When to push back instead

If the request is ambiguous, or you believe it is wrong (it would break an acceptance
criterion, reintroduce a known failure mode from `docs/LEARNINGS.md`, or cross the issue's
Out of scope line), do not guess. Comment on the PR explaining the conflict and asking how
to proceed. Then stop.
