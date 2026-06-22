# agentic-toolkit

A drop-in GitHub layer that turns any repo into an **issue → agent → PR → review →
merge → retro** loop. Write a well-scoped issue, apply a label, and an AI agent
implements it and opens a pull request you review. Every correction can become a
permanent guardrail, so the system gets more reliable the more you use it.

Provider-agnostic with first-class support for **Claude Code** (via
[`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action));
OpenAI Codex, GitHub Copilot, and a generic `repository_dispatch` path are included as
stubs you extend.

> Extracted and generalized from the agentic-workflow layer originally built in a
> personal `journal` project, made stack-agnostic.

---

## How it works

```
write an agent-ready issue
   → auto-label-agent-ready.yml validates it and comments "looks ready"
   → you apply the `agent-ready` label
      → agent-ready-trigger.yml:
           complexity:low/medium → implement → open PR
           complexity:high       → write a plan → wait for /approve-plan
              → plan-approval-gate.yml → implement approved plan → open PR
   → PR opens
      → claude-code-review.yml posts an automated review   (opt-in)
   → you review; comment "@claude ..." to request changes
      → claude-pr-feedback.yml pushes fixes to the PR branch
   → you merge
      → agent-retro.yml proposes a durable guardrail if there's a lesson
   ───────────────────────────────────────────────────────────────────
   cost-report.yml  →  monthly / on-demand spend report over time
```

A human stays in the loop at the points that matter — applying the label, approving
high-complexity plans, reviewing and merging. **The agent never merges its own work.**

The full walkthrough — how to write good issues, complexity routing, the approval gate,
the feedback loop, and the compounding retro — is in
**[docs/AGENTIC_DEVELOPMENT.md](docs/AGENTIC_DEVELOPMENT.md)**.

## What's in the box

| File | Role |
| --- | --- |
| `.github/workflows/agent-ready-trigger.yml` | Fires on the `agent-ready` label; routes by complexity to plan or implement. Multi-provider. |
| `.github/workflows/plan-approval-gate.yml` | Listens for `/approve-plan` on high-complexity issues, then implements the approved plan. |
| `.github/workflows/claude-pr-feedback.yml` | `@claude <instruction>` on a PR → the agent pushes fixes to the branch. Write-access gated. |
| `.github/workflows/agent-retro.yml` | After an agent PR merges, proposes a `LEARNINGS` entry + guardrail test if there's a durable lesson. |
| `.github/workflows/claude-code-review.yml` | **Opt-in** automated PR review (read-only). Cost-aware: parameterized model, draft/docs skip, concurrency-cancel. |
| `.github/workflows/cost-report.yml` | Scheduled + on-demand spend report over a window: runs, durations, runner cost, LLM-cost estimate, trend. |
| `.github/workflows/auto-label-agent-ready.yml` | Validates issue structure and advises; **never** auto-applies the label (by design). |
| `.github/workflows/setup-labels.yml` | One-click sync of `.github/LABELS.yml` into the repo. |
| `.github/dependabot.yml` | Weekly updates for the GitHub Actions used here (supply-chain hygiene). |
| `.github/ISSUE_TEMPLATE/agent-ready.md` | The structured issue template the loop runs on. |
| `.github/PULL_REQUEST_TEMPLATE/agent-generated.md` | Self-review checklist + `Closes #NNN` for agent PRs. |
| `.github/LABELS.yml` | The readiness / output / complexity labels the workflows key on. |
| `.claude/settings.json` | Interactive Claude Code permission allowlist for local work. |
| `CLAUDE.template.md` | Copy to `CLAUDE.md` and fill in — the agent reads it on every run. |
| `docs/AGENTIC_DEVELOPMENT.md` | The system guide. |
| `docs/LEARNINGS.md` | Institutional memory: agent failure modes + guardrails. The retro appends here. |
| `docs/COST.md` | Cost containment knobs + the spend report. |
| `docs/SECURITY.md` | Trust boundary, built-in controls, and hardening by risk level. |

## Adopt it

**Option A — new repo (GitHub template):** click **Use this template** to start a repo
with the whole layer in place, then do the [setup](#setup) below.

**Option B — existing repo (installer):** clone this repo and run the installer against
your project. It won't clobber an existing `CLAUDE.md` or `docs/LEARNINGS.md`, and it
appends to `.gitignore` rather than overwriting:

```bash
git clone https://github.com/patrickisgreat/agentic-toolkit
./agentic-toolkit/install.sh /path/to/your/repo
# re-run with --force to refresh toolkit-owned files (workflows, templates, labels)
```

## Setup

1. **Add the provider secret.** Settings → Secrets and variables → **Secrets**:
   - `CLAUDE_CODE_OAUTH_TOKEN` (default Claude provider). Generate with
     `claude setup-token` in Claude Code.
2. **(Optional) Choose a provider.** Set the `AGENT_PROVIDER` repository **variable** to
   `claude` (default), `openai-codex`, `copilot`, or `custom`. The non-Claude jobs are
   stubs — extend them for your setup.
3. **Sync labels.** Actions → **Setup Labels** → Run workflow (one time).
4. **Write your `CLAUDE.md`.** Copy `CLAUDE.template.md` to `CLAUDE.md` and fill in your
   stack, commands, and conventions. This is the single biggest lever on output quality.
5. **(Optional) Tune cost & enable review.** Set repository **variables** (none required —
   sensible defaults apply): `AGENT_MODEL` (default `sonnet`), `AGENT_PLAN_MODEL` (default
   `opus`), `AGENT_REVIEW_MODEL` (default `sonnet`), `AGENT_MAX_TURNS`, and
   `ENABLE_CLAUDE_REVIEW=true` to switch on automated PR review. See **[docs/COST.md](docs/COST.md)**.
6. **Try it.** Open an issue with the **🤖 Agent-Ready Task** template, fill it out, and
   apply the `agent-ready` label.

## Cost containment

Spend is fully adjustable via repository variables — no file edits. The big lever is
**model tier per job** (frequent work on `sonnet`, rare high-stakes planning on `opus`,
review on `sonnet`/`haiku`), plus opt-in review, turn caps, draft/docs skips, and
concurrency-cancel. The **`cost-report.yml`** workflow reports spend over time (runs,
durations, runner cost, LLM-cost estimate, period-over-period trend) to the job summary —
and can commit a dated report or open a tracking issue. Full guide and preset profiles
(solo / team / quality-first): **[docs/COST.md](docs/COST.md)**.

## Security model

The whole model rests on **only trusted people being able to trigger the agent** (it
treats issue/PR text as instructions). Built in:

- **A human applies `agent-ready`** — the validator only advises. (A label set by
  `GITHUB_TOKEN` also wouldn't fire the trigger; see `docs/LEARNINGS.md`.)
- **`/approve-plan` and `@claude` are gated on write/admin access** — randoms on a public
  repo can't drive the agent. **A human always owns the merge.**
- **Least-privilege job tokens** — the review job is `contents: read` (can't push); only
  the secret `CLAUDE_CODE_OAUTH_TOKEN` reaches the agent.
- **`bypassPermissions` is scoped to ephemeral CI runners** with a repo-scoped token, and
  forced via `claude_args`. Never commit `.claude/settings.local.json`.
- **Fork PRs fail safe** — review uses `pull_request` (no secrets on forks), not
  `pull_request_target`.
- **Built-in human-approval gate (off by default).** The write-capable jobs declare
  `environment: ${{ vars.AGENT_ENVIRONMENT || 'agent' }}`. Add Required reviewers to the
  `agent` environment (Settings → Environments) to make every agent run pause for human
  sign-off — no file edits.

Further hardening (branch protection, action SHA-pinning, secret scanning, spend caps) and
the full threat model: **[docs/SECURITY.md](docs/SECURITY.md)**.
Each built-in control traces to a real failure documented in **[docs/LEARNINGS.md](docs/LEARNINGS.md)**.

## License

[MIT](LICENSE) © 2026 Patrick Bennett
