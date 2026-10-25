---
name: write-agent-guide
description: Create or improve a repo's CLAUDE.md (the agent guide that AGENTS.md and GEMINI.md point at) by filling the agentic-toolkit template from the actual codebase - stack, directory map, exact test/lint/build commands, conventions, off-limits areas, and the agentic-workflow invariants. Use when the user says "write a CLAUDE.md", "fill in the agent guide", "set up AGENTS.md", "the agent keeps guessing our conventions wrong", or after installing the toolkit.
---

# Write the agent guide (CLAUDE.md)

`CLAUDE.md` is the single biggest lever on agent output quality. Every provider reads it on
every run, locally and in CI. `AGENTS.md` (Codex) and `GEMINI.md` (Gemini CLI) are one-line
pointers to it, so there is one file to maintain.

## Steps

1. **Find the starting point.** If `CLAUDE.md` exists, read it; you are improving, not
   replacing. If only `CLAUDE.template.md` exists, copy it to `CLAUDE.md`. If neither exists,
   use the section list below.
2. **Derive every section from the code, not from guesses.** Open the files that answer each
   question:
   - **What this is**: README, package manifest, main entry point. One paragraph plus the
     single invariant a newcomer must not violate.
   - **Stack**: language and version from the manifest or toolchain file, framework, package
     manager, linter, formatter.
   - **Directory map**: a short tree with one-line descriptions of the directories an agent
     will navigate. Keep it to what matters.
   - **How to run tests, lint, and build**: the EXACT commands, from the Makefile, task
     runner, package scripts, or CI workflow. If CI is the real gate, say exactly what CI runs
     on a PR so the agent writes to that bar.
   - **Testing conventions**: where tests live, the naming pattern, the fixture or fake
     strategy, and the rule against real network calls. Point at one sibling test to copy.
   - **Conventions**: the things an agent would otherwise guess wrong. Read a few files in
     each layer and write down what you see: error handling style, naming, module layout,
     logging. Prefer imperative rules with an example path.
   - **Off-limits**: generated files, release and packaging files, migrations, anything a
     human must own. Also: never weaken tests to pass, never commit secrets, Out of scope is
     a hard boundary.
3. **Keep the agentic-workflow invariants** at the bottom. The toolkit's workflows assume:
   - Conventional Commits.
   - Branches `agent/issue-<n>` and `plan/issue-<n>` for the agent flow.
   - PR bodies use `Closes #NNN` with the `#`, un-bolded.
   - Agent PRs carry the `agent-generated` label and use
     `.github/PULL_REQUEST_TEMPLATE/agent-generated.md`.
   - High-complexity work plans into `docs/plans/` first and waits for `/approve-plan`.
   - When blocked or uncertain, comment on the issue and ask.
4. **Add the reassess-before-building rule.** Issues go stale; the agent must reconcile the
   issue's notes against current code and follow reality, noting deviations in the PR.
5. **Make sure the pointers exist.** `AGENTS.md` and `GEMINI.md` should each say the guide
   lives in `CLAUDE.md`. Create them if missing. Make sure `CLAUDE.md` tells the reader to
   also read `docs/LEARNINGS.md`.
6. **Delete every placeholder and template comment.** A `<PLACEHOLDER>` left in the file is
   worse than a missing section because the agent will read it as content.

## Style

- Concrete and imperative. "Run `make test` before finishing" beats "tests should pass".
- Short. An agent reads this on every task; every line costs tokens on every run. Cut
  anything derivable from the code in a minute.
- Keep the why in `docs/LEARNINGS.md`; keep the rule in `CLAUDE.md`.
