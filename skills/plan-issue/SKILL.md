---
name: plan-issue
description: Write a structured implementation plan for a complexity:high GitHub issue without writing application code, save it to docs/plans/, commit it to a plan/issue-N branch, and ask for /approve-plan. Use when the user says "plan issue 42", "write a plan for this", "this needs a planning phase", or when an agent-ready issue carries the complexity:high label.
---

# Plan an issue (no implementation)

High-complexity work plans first so a human signs off on the approach before any code is
written. Your job here is to PLAN, not implement.

## Inputs

- An issue number. If the user did not give one, ask, or infer it from the branch name
  (`plan/issue-N`, `agent/issue-N`).

## Steps

1. **Read the issue in full:**

   ```bash
   gh issue view <N> --json title,body,labels,comments
   ```

2. **Read the agent guide and the learnings.** `CLAUDE.md` at the repo root is the project's
   agent guide for every agent (`AGENTS.md` and `GEMINI.md` point at it). Read
   `docs/LEARNINGS.md` too, so the plan does not repeat a known failure mode.
3. **Read the key files** named in the issue's Technical Notes, plus whatever they import or
   are imported by, until you understand the shape of the change. Reconcile the issue
   against current code: issues are written ahead of time and the codebase moves. Where
   the issue is stale, plan against reality and say so in the plan.
4. **Write the plan** to `docs/plans/YYYY-MM-DD-NNN-<type>-<short-title>-plan.md`, where
   `NNN` is the next sequence number for that date (001 if none) and `<type>` is `feat`,
   `fix`, `refactor`, or `chore`. Use this structure:

   ```markdown
   # Plan: <issue title> (#N)

   ## Problem frame
   What is wrong or missing, and for whom. One paragraph.

   ## Requirements
   The acceptance criteria from the issue, restated as numbered requirements.

   ## Scope boundaries
   In scope / out of scope, copied from the issue and tightened where the code demands it.

   ## Key technical decisions
   Each decision: the options considered, the one chosen, and why. This is the section the
   human is approving.

   ## Implementation units
   One unit per PR-sized chunk, in order. For each:
   - **Goal**
   - **Files** (create / modify)
   - **Approach**
   - **Test scenarios** (what a test must assert, where it lives)

   ## Documentation targets
   Every doc surface the change must touch.

   ## Risks and open questions
   Anything that needs a human answer before or during implementation.
   ```

5. **Commit the plan** on a branch named `plan/issue-<N>` and push it. Commit message:
   `docs(plan): implementation plan for #<N>`.
6. **Comment on the issue** with a link to the plan file on that branch and this text:

   > Implementation plan is ready for review. Reply `/approve-plan` to begin
   > implementation, or comment with feedback to revise the plan.

## Hard rules

- Do NOT write application code.
- Do NOT open a pull request.
- If the issue is ambiguous enough that two reasonable plans differ materially, write the
  plan for the reading you consider best, and list the alternative under open questions.
  If you cannot plan at all without an answer, comment on the issue asking, and stop.

## Revising after feedback

When a human comments with feedback instead of `/approve-plan`, update the same plan file on
the same branch, push, and comment again with what changed. Do not create a second plan file.
