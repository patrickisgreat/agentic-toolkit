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
   → you review; comment "@claude ..." to request changes
      → claude-pr-feedback.yml pushes fixes to the PR branch
   → you merge
      → agent-retro.yml proposes a durable guardrail if there's a lesson
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
| `.github/workflows/auto-label-agent-ready.yml` | Validates issue structure and advises; **never** auto-applies the label (by design). |
| `.github/workflows/setup-labels.yml` | One-click sync of `.github/LABELS.yml` into the repo. |
| `.github/ISSUE_TEMPLATE/agent-ready.md` | The structured issue template the loop runs on. |
| `.github/PULL_REQUEST_TEMPLATE/agent-generated.md` | Self-review checklist + `Closes #NNN` for agent PRs. |
| `.github/LABELS.yml` | The readiness / output / complexity labels the workflows key on. |
| `.claude/settings.json` | Interactive Claude Code permission allowlist for local work. |
| `CLAUDE.template.md` | Copy to `CLAUDE.md` and fill in — the agent reads it on every run. |
| `docs/AGENTIC_DEVELOPMENT.md` | The system guide. |
| `docs/LEARNINGS.md` | Institutional memory: agent failure modes + guardrails. The retro appends here. |

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
5. **Try it.** Open an issue with the **🤖 Agent-Ready Task** template, fill it out, and
   apply the `agent-ready` label.

## Security model

- **A human applies `agent-ready`** — the validator only advises. (A label set by
  `GITHUB_TOKEN` also wouldn't fire the trigger; see `docs/LEARNINGS.md`.)
- **`/approve-plan` and `@claude` are gated on write/admin access** — randoms on a public
  repo can't drive the agent.
- **`bypassPermissions` is scoped to ephemeral CI runners** with a repo-scoped token, and
  forced via `claude_args` in the workflow. Never commit `.claude/settings.local.json`.

These aren't arbitrary — each traces to a real failure documented in
**[docs/LEARNINGS.md](docs/LEARNINGS.md)**.

## License

[MIT](LICENSE) © 2026 Patrick Bennett
