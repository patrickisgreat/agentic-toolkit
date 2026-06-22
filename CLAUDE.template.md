<!--
  This is a TEMPLATE. Copy it to CLAUDE.md at your repo root and fill in the
  <PLACEHOLDERS>. Delete this comment and any sections that don't apply.

  CLAUDE.md is the single most important input to agent output quality: the agent
  reads it on every run (local and CI). Be concrete and imperative. Keep the
  agentic-workflow invariants near the bottom — those are what this toolkit's
  workflows assume.
-->

# CLAUDE.md

Project context for AI coding agents (Claude Code, both local and CI). Read this first on
every task. It tells you the stack, how the code is organized, how to run and test things,
the conventions to follow, and what is off-limits.

Also read **docs/LEARNINGS.md** — failure modes captured from real agent runs and the "why"
behind the rules here. The rules below are imperative; LEARNINGS explains where they came from.

---

## What this is

<!-- One paragraph: what the project does, who uses it, and the single most important
     invariant a newcomer must not violate. -->

<PROJECT_ONE_PARAGRAPH_DESCRIPTION>

## Stack

<!-- Language + version, framework(s), key libraries, package manager, linter, formatter. -->

- **Language:** <LANGUAGE / VERSION>
- **Framework / key libs:** <...>
- **Package manager:** <...>
- **Lint / format:** <...>

## Directory map

<!-- A short tree with one-line descriptions. Agents navigate by this — keep it current. -->

```
<path/>     <what lives here>
<path/>     <what lives here>
```

## How to run tests, lint, and build

<!-- The EXACT commands. Prefer a Makefile / task runner so there's one right way.
     If CI is the real gate (the agent's runner may lack your toolchain), say so. -->

```bash
<build command>
<test command>
<lint command>
<format command>
```

### Testing — match these conventions

- **CI is the real gate.** State exactly what CI runs on a PR (format check, vet/lint,
  build, test) so the agent writes to that bar.
- **Tests live <where>** and follow <pattern>. Read a sibling test before writing yours.
- **Every behavior change ships with tests.** When you change output or behavior, grep for
  tests asserting the old contract and update them.
- **Never call real network services in tests.** Use the existing fakes/fixtures. A test
  that needs the network is wrong — make the boundary injectable instead.
- **The CI agent may not have your toolchain.** If you can't run the suite, write tests
  rigorously and trace them against your implementation; the PR's CI executes them. Never
  knowingly open a red PR. (See docs/LEARNINGS.md.)

## Working from an issue — reassess before you build

Issues are written ahead of time and the codebase keeps moving. **Before you implement,
reconcile the issue's notes against the current code.** If it references a file, command, or
pattern that has since changed, follow current reality, not the stale instruction, and note
the deviation in the PR body. If the divergence makes the intended approach wrong, **stop and
comment on the issue** rather than building the wrong thing.

## Conventions to follow

<!-- Project-specific code conventions. Examples to adapt: -->

- **Errors are wrapped with context and returned, not logged-and-swallowed.** Match the
  style in neighboring files.
- **Keep it lint-clean and format-clean** — CI fails otherwise. Run <format/lint> before finishing.
- <add the conventions an agent would otherwise guess wrong>

## Off-limits / be careful

<!-- Hard lines. Be explicit — "Out of scope" in an issue is also a hard line. -->

- Do **not** edit <release/packaging/generated files> unless the issue is explicitly about them.
- Do **not** weaken the test setup to make something pass.
- Do **not** print, commit, or hardcode secrets.
- Stay inside the issue's **"Out of scope"** — it's a hard boundary.

---

## Agentic-workflow invariants (required by agentic-toolkit)

These are assumed by the workflows in `.github/workflows/`. Keep them:

- **Commit style is Conventional Commits** (`feat:`, `fix:`, `chore:`, …).
- **Branches:** `feature/…`, `fix/…`; the agent flow uses `agent/issue-<n>` and
  `plan/issue-<n>`.
- **PR issue links use `Closes #NNN`** (with the `#`, un-bolded) — a bare number or a
  bolded keyword won't auto-close. (See docs/LEARNINGS.md.)
- **Agent-generated PRs carry the `agent-generated` label** and use the
  `.github/PULL_REQUEST_TEMPLATE/agent-generated.md` template.
- **High-complexity work plans first** into `docs/plans/` and waits for `/approve-plan`.
- **If blocked or genuinely uncertain, comment on the issue and ask** — don't guess.
