# Agentic Development

How this toolkit turns a GitHub repo into an **issue → agent → PR → review → merge →
retro** loop, and how to drive it well. This is the guide referenced from the
`agent-ready` issue template.

The premise: a well-scoped issue is a specification. If you write the spec clearly
enough, an AI agent can implement it, open a pull request, and you review the PR
instead of writing the code. The toolkit is the plumbing that makes that loop safe,
repeatable, and self-improving.

---

## The loop

```
        ┌─────────────────────────────────────────────────────────────────┐
        │                                                                   │
   you write an          auto-label-agent-ready.yml                         │
   "agent-ready"   ───▶  validates structure, comments                      │
   issue                 "looks ready — apply the label"                    │
        │                                                                   │
        ▼                                                                   │
   you apply the         agent-ready-trigger.yml                            │
   `agent-ready`   ───▶  routes by complexity:                              │
   label                   • low/medium → implement → open PR               │
        │                  • high       → write a plan, ask for /approve    │
        ▼                                                                   │
   complexity:high?  ──▶  plan-approval-gate.yml                            │
   you comment            you /approve-plan → agent implements → PR         │
   /approve-plan                                                            │
        │                                                                   │
        ▼                                                                   │
   PR is open       ───▶  you review. Need changes? comment "@claude ..."   │
        │                 claude-pr-feedback.yml pushes fixes to the branch │
        ▼                                                                   │
   you merge        ───▶  agent-retro.yml reflects: did this need           │
                          correction? If there's a durable lesson, it       │
                          opens a PR adding a guardrail ──────────────────┘
                          (LEARNINGS entry + a test) so the next run
                          doesn't repeat the mistake.
```

Two things make this more than "an agent on a label":

1. **A human is always in the loop at the points that matter** — applying the label,
   approving high-complexity plans, reviewing and merging the PR. The agent never
   merges its own work.
2. **The loop compounds.** Every correction you make can become a permanent guardrail
   via the retro workflow, so the system gets more reliable the more you use it.

---

## Writing a good agent-ready issue

The agent has no institutional knowledge. It knows what's in the repo and what's in the
issue — nothing else. A vague issue produces a vague PR. The `agent-ready` issue template
(`.github/ISSUE_TEMPLATE/agent-ready.md`) is structured to force the inputs an agent needs:

| Section | Why it matters |
| --- | --- |
| **Summary** | One sentence. If you need more, the scope is too big — split it. |
| **Context** | The *why*. Agents make better trade-offs when they understand intent. |
| **Acceptance Criteria** | The definition of "done", as checkable boxes. This is the contract the agent (and your review) is graded against. |
| **Scope (in / out)** | "Out of scope" is a **hard boundary**. This is your primary tool against scope creep. |
| **Technical Notes** | Key files, patterns to follow (linked, not assumed), dependencies, testing approach. This is how the PR matches your codebase instead of inventing its own style. |
| **Complexity** | Routes execution (see below). |

**Good issues are specific.** "Improve error handling" is not actionable. "When
`config.Load` hits a missing file, return a wrapped error naming the path instead of
panicking; add a table test in `config_test.go`" is.

The auto-validator (`auto-label-agent-ready.yml`) checks that the required sections are
present and leaves an advisory comment — but it does **not** judge whether your criteria
are *good*. That's on you.

---

## Complexity routing

Apply one complexity label. It changes how the agent executes:

- **`complexity:low`** — single file, obvious pattern. Implements directly.
- **`complexity:medium`** — multiple files, established patterns. Implements directly.
- **`complexity:high`** — architectural decisions or new patterns. The agent **plans
  first**: it writes a structured plan to `docs/plans/`, commits it to a `plan/issue-N`
  branch, and comments asking for approval. Nothing is implemented until a human with
  write access comments `/approve-plan`.

No complexity label is treated as low/medium (direct execution). Use `complexity:high`
whenever you'd want to see the approach before any code is written.

### The planning gate (high complexity)

1. You apply `agent-ready` to a `complexity:high` issue.
2. `agent-ready-trigger.yml` runs the agent in **plan-only** mode — it writes
   `docs/plans/YYYY-MM-DD-NNN-<type>-<title>-plan.md` and comments asking for review.
3. You read the plan. To proceed, comment `/approve-plan`. To revise, comment feedback
   and re-trigger.
4. `plan-approval-gate.yml` verifies you have write/admin access, then runs the agent to
   implement the approved plan and open a PR.

This gate is the difference between "the agent guessed at an architecture and wrote 800
lines" and "you signed off on the approach first."

---

## Reviewing and iterating on the PR

Agent PRs use the `agent-generated` PR template — a self-review checklist plus the
`Closes #NNN` link that auto-closes the issue on merge.

You review like any PR. When you want changes, **comment `@claude <instruction>`** on the
PR (or in a PR review). `claude-pr-feedback.yml`:

- checks the commenter has **write/admin** access (so randoms on a public repo can't
  drive the agent),
- checks out the PR's head branch,
- makes the change and pushes it back to the same branch, re-running CI.

This closes the in-PR feedback loop. The base trigger is one-shot-per-issue; `@claude`
is how you steer after the first PR exists.

**You merge.** The agent never does.

---

## The compounding engine: Agent Retro

When an `agent-generated` PR merges, `agent-retro.yml` reflects on it:

- Did it need correction before landing? (Signals: multiple fix-up commits, `@claude`
  feedback, changes-requested reviews, CI that failed before passing, drift from the
  issue's intent.)
- Is there a **generalizable** lesson, or was it a one-off?

If — and only if — there's a recurring *class* of mistake, the retro opens its own PR
(`retro/pr-N`) that appends a **Symptom → Root cause → Guardrail** entry to
`docs/LEARNINGS.md` and, where feasible, adds a **test** that asserts the correct
behavior (passes on current `main`, fails only on regression). A human reviews that PR.

A clean first-try merge produces nothing. A genuine one-off produces nothing. This is
deliberate: a wrong test gets reverted, but a wrong "lesson" misleads every future run.
The retro is conservative on purpose.

`docs/LEARNINGS.md` is the institutional memory the whole system reads before
implementing. It's how the loop gets smarter instead of repeating itself.

---

## Labels

`/.github/LABELS.yml` defines the labels the workflows key on. Run the **Setup Labels**
workflow once (Actions → Setup Labels → Run workflow) to sync them into your repo.

- **Readiness:** `agent-ready` (fires the agent), `agent-candidate` (screener flagged,
  needs human review), `needs-planning`.
- **Output:** `agent-generated` (PR was created by an agent; the retro keys on this).
- **Complexity:** `complexity:low` / `complexity:medium` / `complexity:high` (routing).

---

## Setup & configuration

See the [README](../README.md) for the full quick-start. In short:

1. **Install the layer** (use this repo as a GitHub template, or run `install.sh` against
   an existing repo).
2. **Add the provider secret.** For the default Claude provider, add
   `CLAUDE_CODE_OAUTH_TOKEN` under Settings → Secrets and variables → Secrets.
3. **(Optional) Choose a provider.** Set the `AGENT_PROVIDER` repository *variable* to
   `claude` (default), `openai-codex`, `copilot`, or `custom`. The non-Claude jobs are
   stubs you extend for your setup.
4. **Sync labels.** Run the Setup Labels workflow once.
5. **Write a `CLAUDE.md`.** Copy `CLAUDE.template.md` to `CLAUDE.md` and fill in your
   stack, commands, and conventions. The agent reads this on every run — it's the single
   biggest lever on output quality.

---

## Security model

Running an agent with write access off a label is powerful; the toolkit constrains it:

- **A human applies `agent-ready`.** The auto-validator only *advises*. (It also
  technically *can't* auto-apply it usefully — a label set by `GITHUB_TOKEN` doesn't fire
  the trigger. See `docs/LEARNINGS.md`.)
- **`/approve-plan` and `@claude` are gated on write/admin access.** Anyone can comment on
  a public repo; only collaborators can drive the agent. The workflows check the
  commenter's permission level and refuse otherwise.
- **`bypassPermissions` is scoped to ephemeral CI runners** with a repo-scoped token —
  not your laptop. The committed `.claude/settings.json` is the *interactive* allowlist;
  the headless permission mode is forced in the workflow (see `docs/LEARNINGS.md` for why
  both exist and why they differ).
- **Never commit `.claude/settings.local.json`** — it's gitignored, and in CI it would
  override the workflow's permission mode.

---

## When the agent should stop and ask

The prompts instruct the agent: if it's blocked or genuinely uncertain, **comment on the
issue asking for clarification rather than guessing**. A good agent-ready issue rarely
triggers this — but it's the right failure mode when scope or intent is ambiguous.
