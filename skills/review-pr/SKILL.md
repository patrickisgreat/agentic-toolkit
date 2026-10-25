---
name: review-pr
description: Post one focused, cost-aware review comment on a pull request checking correctness, security, scope drift against the linked issue, test coverage, and CLAUDE.md convention violations, with findings as file:line bullets. Never pushes code, never formally approves or requests changes. Use when the user says "review PR 57", "look over this PR", "give me a second pair of eyes before I merge", or "what's wrong with this diff".
---

# Review a pull request

You are a second pair of eyes before the human's own review, not the merge decision. Keep
it tight: a short high-signal review is more useful than an exhaustive one.

## Steps

1. **Read the diff and the PR metadata:**

   ```bash
   gh pr view <PR> --json title,body,closingIssuesReferences,files,commits
   gh pr diff <PR>
   ```

   If the PR closes an issue, read the issue too. Scope drift is measured against it.
2. **Read `CLAUDE.md` and `docs/LEARNINGS.md`** so the review reflects this project's
   conventions and its known failure modes, not generic taste.
3. **Review in this priority order.** Stop adding findings when you run out of real ones.
   - Correctness bugs and broken edge cases.
   - Security: injection, secrets in the diff, missing authorization, unsafe input handling.
   - Scope drift versus the linked issue and its Out of scope section.
   - Missing or weak tests for the behavior that changed. A test that only exercises the
     happy path of new code counts as weak.
   - Violations of the conventions in `CLAUDE.md`.
4. **Post exactly one comment.** Start it with the marker line `<!-- agent-code-review -->`.
   If a comment with that marker already exists on the PR, edit it rather than adding a
   second one:

   ```bash
   gh pr view <PR> --json comments --jq '.comments[] | select(.body | startswith("<!-- agent-code-review -->")) | .id'
   ```

   Structure:
   - one-line verdict
   - a short bulleted list of concrete findings, each with `path:line` where possible
   - a `Nits` list if any, kept separate so the reader can skip it

   If the PR looks good, say so briefly. Do not invent findings to fill a list.

## Hard rules

- Do NOT push code to the PR.
- Do NOT approve or request changes through the formal review API. A human owns the merge
  decision; the comment is advisory.
- Do not restate the diff back to the author. Name what is wrong, where, and why it matters.
