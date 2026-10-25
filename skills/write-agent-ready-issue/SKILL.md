---
name: write-agent-ready-issue
description: Draft, validate, and file a GitHub issue that an AI agent can implement unattended, using the agentic-toolkit agent-ready template (Summary, Context, Acceptance Criteria, Scope in/out, Technical Notes, Complexity). Use when the user wants to "write an issue for the agent", "make this agent-ready", "scope this task", "file a ticket the bot can pick up", or asks why the validator did not mark an issue ready.
---

# Write an agent-ready issue

An agent-ready issue is a specification. If it is written clearly enough, an agent can
implement it, open a PR, and the human reviews instead of writing code. This skill turns a
rough request into that specification and files it.

## Steps

1. **Gather the intent.** From the conversation and the codebase, work out the single change
   being asked for. If it needs more than one sentence to summarize, it is two issues; say
   so and split it.
2. **Ground it in the code.** Open the files the change touches and find a sibling
   implementation to point at. Technical Notes must name real paths and real patterns, never
   "follow project conventions". Read `CLAUDE.md` and `docs/LEARNINGS.md` if present so the
   issue does not ask for something a known failure mode forbids.
3. **Draft the body** using `references/issue-template.md`. Fill every section:
   - **Summary**: one sentence.
   - **Context**: the why. Who uses it, what breaks without it, how it fits.
   - **Acceptance Criteria**: checkboxes, each independently verifiable. Include error cases.
     Enumerate every documentation surface that must change. "Done" includes docs.
   - **Scope**: explicit In scope and Out of scope lists. Out of scope is a hard boundary
     the agent will not cross, so put future enhancements there deliberately.
   - **Technical Notes**: key files (to modify and to use as reference), patterns to follow,
     dependencies, testing approach with test file locations.
   - **Complexity**: pick exactly one label. See routing below.
4. **Validate** against the same checks the CI validator runs (see below). Fix anything missing.
5. **Show the draft** to the user before filing unless they already asked you to file it.
6. **File it** with the GitHub CLI, applying the complexity label but NOT the `agent-ready`
   label:

   ```bash
   gh issue create --title "<title>" --body-file /path/to/body.md --label "complexity:medium"
   ```

   Tell the user to apply `agent-ready` themselves. A label applied by automation with the
   default token does not fire the trigger workflow, and once present a human can no longer
   fire it by adding it. The human applying the label is the gate.

## Complexity routing

- `complexity:low`: single file, obvious pattern. Agent implements directly.
- `complexity:medium`: several files, established patterns. Agent implements directly.
- `complexity:high`: architectural decisions or new patterns. Agent writes a plan to
  `docs/plans/` first and waits for a human to comment `/approve-plan`. Choose this
  whenever the user would want to see the approach before any code exists.

## Validation checks (mirror of `auto-label-agent-ready.yml`)

The issue body must contain:

- the headings `## Summary`, `## Context`, `## Acceptance Criteria`, `## Scope`, `## Technical Notes`
- both `**In scope:**` and `**Out of scope:**`
- at least one checkbox line matching `- [ ]` or `- [x]`

If the validator in the target repo has been customized, read
`.github/workflows/auto-label-agent-ready.yml` and use its `requiredSections` list instead.

## Red flags to fix before filing

- Vague verbs: "improve", "enhance", "clean up", "make better".
- Unrelated changes bundled together.
- Patterns assumed rather than linked to a file.
- External blockers: a missing API key, a dependency not yet installed, a decision not yet made.
- Acceptance criteria that cannot be checked by reading the diff or running a test.
