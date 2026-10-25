---
name: retro
description: Run a retrospective on a merged agent-generated pull request - decide whether it needed correction before landing and, only if there is a generalizable class of mistake, open a retro/pr-N PR that appends a Symptom → Root cause → Guardrail entry to docs/LEARNINGS.md plus an enforcing test. Use when the user says "retro PR 57", "did we learn anything from that merge", "add a learning", or "capture this lesson as a guardrail".
---

# Retrospective on a merged PR

The loop compounds because corrections become permanent guardrails. The retro is
deliberately conservative: a wrong test gets reverted, but a wrong "lesson" misleads every
future run. When unsure whether something is a durable class, propose nothing.

## Steps

1. **Read the merged PR and its history:**

   ```bash
   gh pr view <PR> --json title,body,commits,comments,reviews,closingIssuesReferences,files
   gh pr diff <PR>
   ```

   Signals it needed correction:
   - several fix-up commits after the first push
   - `@agent` or `@claude` feedback comments
   - changes-requested reviews
   - CI that failed before passing (`gh run list --branch <head> --json conclusion`)
   - drift from the closed issue's intent (read the issue)

2. **Read `docs/LEARNINGS.md` and `CLAUDE.md`** so you do not duplicate an existing lesson.
   If the lesson is already there, stop and say so.
3. **Decide.**
   - Merged clean, or the only problem was a genuine one-off: do NOT open a PR. Post a
     one-line comment on the PR: `Retro: no durable lesson (merged clean / one-off).` Stop.
   - A recurring class of mistake that future runs would repeat: continue.
4. **Open the retro PR** on branch `retro/pr-<N>`:
   - Append an entry to `docs/LEARNINGS.md` at the top, newest first, in the existing format:

     ```markdown
     ## <One-line lesson, imperative>

     **Symptom:** what went wrong or was observed.

     **Root cause:** why, mechanically.

     **Guardrail:** the durable change that prevents the class. Name the test or rule.
     ```

   - Prefer an ENFORCEABLE guardrail. Where the lesson can be caught by a test, add or extend
     a test asserting the CORRECT behavior. It must pass against current `main` (the mistake
     is already fixed) and fail only on regression. Only add a terse `CLAUDE.md` rule when a
     test is not feasible.
   - PR title: `Retro: <one-line lesson> (from #<N>)`.
   - PR body: link the source PR and the closed issue, state the root cause, and explain why
     the guardrail prevents the class. Do NOT add the `agent-generated` label; the retro
     must not trigger another retro.

## Hard rules

- Stay tightly scoped: the LEARNINGS entry, the guardrail test, and at most a minimal
  `CLAUDE.md` rule. Do NOT change application code or unrelated tests.
- Do NOT re-implement or "improve" the merged PR.
- One lesson per retro PR. If you find two, open two.

## Interactive use without a PR

If the user describes a mistake from a session rather than a merged PR, apply step 3 to the
description, and if it qualifies, write the LEARNINGS entry and test on a `retro/<slug>`
branch and open the PR the same way.
