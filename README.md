# agentic-toolkit

A drop-in GitHub layer that turns any repo into an **issue → agent → PR → review → merge →
retro** loop.

Write a well-scoped issue, apply a label, and an AI agent implements it and opens a pull
request for you to review. A human stays in the loop at every point that matters, and every
correction you make can become a permanent guardrail — so the system gets more reliable the
more you use it.

**Bring your own agent.** One repository variable picks between **Claude Code**, **OpenAI
Codex**, and **Google Gemini**; everything else in the loop is identical.

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
      → agent-code-review.yml posts an automated review          (opt-in)
   → you review; comment "@agent ..." to request changes
      → agent-pr-feedback.yml pushes fixes to the PR branch
   → you merge
      → agent-retro.yml proposes a durable guardrail if there's a lesson
   ───────────────────────────────────────────────────────────────────
   cost-report.yml  →  monthly / on-demand spend report over time
```

Two things make this more than "an agent on a label":

- **The human gates are where they belong** — applying the label, approving
  high-complexity plans, reviewing and merging. **The agent never merges its own work.**
- **The loop compounds.** After an agent PR merges, the retro asks whether it needed
  correcting and, if the lesson generalizes, opens its own PR adding a `LEARNINGS` entry
  and a guardrail test. Next run doesn't repeat the mistake.

The full walkthrough — writing good issues, complexity routing, the approval gate, the
feedback loop, the compounding retro — is in
**[docs/AGENTIC_DEVELOPMENT.md](docs/AGENTIC_DEVELOPMENT.md)**.

## Install

**New repo:** click **Use this template** to start with the whole layer in place.

**Existing repo:** clone this repo and run the installer against your project. It won't
clobber your `CLAUDE.md` or `docs/LEARNINGS.md`, and it appends to `.gitignore` rather than
overwriting it:

```bash
git clone https://github.com/patrickisgreat/agentic-toolkit
./agentic-toolkit/install.sh /path/to/your/repo
# re-run with --force to refresh toolkit-owned files (workflows, templates, labels)
```

Then configure it:

1. **Add your provider's secret.** Settings → Secrets and variables → **Secrets** — see the
   table below. For the Claude default, generate the token with `claude setup-token`.
2. **Set `AGENT_PROVIDER`** (Settings → **Variables**) unless you want Claude.
3. **Sync labels.** Actions → **Setup Labels** → Run workflow. One time.
4. **Write your `CLAUDE.md`.** Copy `CLAUDE.template.md` and fill in your stack, commands,
   and conventions. This is the single biggest lever on output quality.
5. **(Optional) Tune cost and turn on review.** All defaults are sensible; see
   [Cost](#cost-containment).
6. **Try it.** Open an issue with the **🤖 Agent-Ready Task** template, fill it out, and
   apply the `agent-ready` label.

## Choose your agent

| `AGENT_PROVIDER` | Runs | Secret it needs |
| --- | --- | --- |
| `claude` _(default — unset means this)_ | Claude Code, via [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action) | `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` |
| `openai` | OpenAI Codex CLI, headless (`codex exec`) | `OPENAI_API_KEY` |
| `gemini` | Google Gemini CLI, headless (`gemini --prompt`) | `GEMINI_API_KEY` |
| `custom` | Nothing — fires a `repository_dispatch` event for a listener you write | — |

All three hosted providers run through a single composite action,
**`.github/actions/agent-run`**. It is the only place a vendor is named, so swapping or
adding a provider is one file rather than five workflows. It also normalizes the awkward
parts: full-auto permissions per CLI, a fail-fast check when the selected provider's secret
is missing, and — for Codex and Gemini, which don't manage git themselves — a deterministic
commit/push/open-PR fallback if the agent leaves work behind.

**One agent guide, three filenames.** `CLAUDE.md` is the source of truth. `AGENTS.md` (which
Codex loads) and `GEMINI.md` (which Gemini loads) are one-line pointers to it, and every
prompt names it explicitly. Write your conventions once.

## What's in the box

| File | Role |
| --- | --- |
| `.github/actions/agent-run/action.yml` | The provider seam. Runs one agentic task on Claude / Codex / Gemini; the only vendor-aware file. |
| `.github/workflows/agent-ready-trigger.yml` | Fires on the `agent-ready` label; routes by complexity to plan or implement. |
| `.github/workflows/plan-approval-gate.yml` | Listens for `/approve-plan` on high-complexity issues, then implements the approved plan. |
| `.github/workflows/agent-pr-feedback.yml` | `@agent <instruction>` on a PR → the agent pushes fixes to the branch. Write-access gated. |
| `.github/workflows/agent-retro.yml` | After an agent PR merges, proposes a `LEARNINGS` entry + guardrail test if there's a durable lesson. |
| `.github/workflows/agent-code-review.yml` | **Opt-in** automated PR review (read-only). Cost-aware: parameterized model, draft/docs skip, concurrency-cancel. |
| `.github/workflows/cost-report.yml` | Scheduled + on-demand spend report over a window: runs, durations, runner cost, LLM-cost estimate, trend. |
| `.github/workflows/auto-label-agent-ready.yml` | Validates issue structure and advises; **never** auto-applies the label (by design). |
| `.github/workflows/setup-labels.yml` | One-click sync of `.github/LABELS.yml` into the repo. |
| `.github/dependabot.yml` | Weekly updates for the GitHub Actions used here (supply-chain hygiene). |
| `.github/ISSUE_TEMPLATE/agent-ready.md` | The structured issue template the loop runs on. |
| `.github/PULL_REQUEST_TEMPLATE/agent-generated.md` | Self-review checklist + `Closes #NNN` for agent PRs. |
| `.github/LABELS.yml` | The readiness / output / complexity labels the workflows key on. |
| `.claude/settings.json` | Interactive Claude Code permission allowlist for local work. |
| `CLAUDE.template.md` | Copy to `CLAUDE.md` and fill in — every agent reads it on every run. |
| `AGENTS.md` · `GEMINI.md` | Pointers so Codex and Gemini find `CLAUDE.md`. |
| `docs/AGENTIC_DEVELOPMENT.md` | The system guide. |
| `docs/LEARNINGS.md` | Institutional memory: agent failure modes + guardrails. The retro appends here. |
| `docs/COST.md` | Cost containment knobs + the spend report. |
| `docs/SECURITY.md` | Trust boundary, built-in controls, and hardening by risk level. |

## Cost containment

Spend is fully adjustable via repository variables — no file edits, and the knobs are the
same on every provider. The big lever is **model tier per job**: frequent work on a mid
tier (`AGENT_MODEL`), rare high-stakes planning on the top tier (`AGENT_PLAN_MODEL`), review
on whatever's cheap enough to run always (`AGENT_REVIEW_MODEL`). On top of that: review is
opt-in (`ENABLE_AGENT_REVIEW`), turn caps (`AGENT_MAX_TURNS`), draft/docs skips, and
concurrency-cancel.

**`cost-report.yml`** reports spend over time — runs, durations, runner cost, LLM-cost
estimate, period-over-period trend — to the job summary, and can commit a dated report or
open a tracking issue. Full guide and preset profiles (solo / team / quality-first):
**[docs/COST.md](docs/COST.md)**.

## Security model

The whole model rests on **only trusted people being able to trigger the agent** — it treats
issue and PR text as instructions. Built in:

- **A human applies `agent-ready`** — the validator only advises. (A label set by
  `GITHUB_TOKEN` also wouldn't fire the trigger; see `docs/LEARNINGS.md`.)
- **`/approve-plan` and `@agent` are gated on write/admin access** — randoms on a public
  repo can't drive the agent. **A human always owns the merge.**
- **Least-privilege job tokens** — the review job is `contents: read` (it can't push), and
  only your provider's model credential reaches the agent.
- **Full-auto mode is scoped to ephemeral CI runners** with a repo-scoped token. Headless
  CI can't answer an approval prompt, so each CLI runs unattended — the job's `permissions:`
  block is the real boundary, not the agent's sandbox. Never commit
  `.claude/settings.local.json`.
- **Fork PRs fail safe** — review uses `pull_request` (no secrets on forks), not
  `pull_request_target`, and the feedback loop declines fork branches it can't push to.
- **Untrusted text never reaches a shell** — issue titles and comment bodies go to the
  agents via env vars and stdin, never a command line.
- **Built-in human-approval gate (off by default).** The write-capable jobs declare
  `environment: ${{ vars.AGENT_ENVIRONMENT || 'agent' }}`. Add Required reviewers to the
  `agent` environment (Settings → Environments) to make every agent run pause for human
  sign-off — no file edits.

Further hardening (branch protection, action SHA-pinning, secret scanning, spend caps) and
the full threat model: **[docs/SECURITY.md](docs/SECURITY.md)**. Each built-in control traces
to a real failure documented in **[docs/LEARNINGS.md](docs/LEARNINGS.md)**.

## License

[MIT](LICENSE) © 2026 Patrick Bennett
