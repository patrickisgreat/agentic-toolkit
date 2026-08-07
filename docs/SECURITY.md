# Security model

Running an AI agent with write access, triggered from GitHub events, is powerful — and a
real attack surface. This document states the **trust boundary**, the controls already
built in, and the hardening you should add for your org's risk level.

> **The one rule that matters most:** the agent treats issue and PR text as *instructions*.
> Anyone who can trigger the agent can, in effect, tell it what to do. So the entire model
> rests on **only trusted people being able to trigger it.** Everything below enforces or
> strengthens that.

---

## Built-in controls

These ship in the workflows as-is:

1. **Human-in-the-loop at every mutating step.** The agent runs only when a human applies
   the `agent-ready` label, approves a high-complexity plan (`/approve-plan`), or mentions
   it on a PR (`@agent`). **The agent never merges its own PR** — a human owns the merge.

2. **Write/admin permission gates.** `agent-pr-feedback.yml` and `plan-approval-gate.yml`
   check the commenter's repo permission level and **refuse anyone below write/admin**.
   This is what stops a random account on a public repo from driving the agent via
   `@agent …` or `/approve-plan`.

3. **No silent auto-trigger.** `auto-label-agent-ready.yml` is comment-only — it never
   applies the label (and couldn't usefully: a `GITHUB_TOKEN`-applied label doesn't fire
   the trigger). A human deliberately starts every run.

4. **Least-privilege job tokens.** Each workflow declares the minimum `permissions:` it
   needs. The **review job is `contents: read`** — even if its prompt were subverted, the
   job token can't push code. Only the implementation jobs get `contents: write`, and only
   because they must create a branch and PR.

5. **Scoped secret exposure.** The only secrets handed to the agent are the model
   credential for your provider (`CLAUDE_CODE_OAUTH_TOKEN` / `ANTHROPIC_API_KEY`,
   `OPENAI_API_KEY`, or `GEMINI_API_KEY`) and the job's own `GITHUB_TOKEN`. No cloud keys,
   deploy creds, or other secrets are placed in the agent's environment by these workflows.
   Configure only the provider you actually use — an unset secret is an empty string, and
   `.github/actions/agent-run` fails fast with a clear message if the selected provider's
   credential is missing.

6. **Full-auto mode is confined to ephemeral CI runners** with a repo-scoped token — not a
   developer laptop. Headless CI can't answer a tool-approval prompt, so every provider
   runs unattended: Claude `--permission-mode bypassPermissions`, Codex
   `--dangerously-bypass-approvals-and-sandbox`, Gemini `--yolo`. **The job's
   `permissions:` block, not the agent's own sandbox, is the real boundary** — which is why
   the review job is `contents: read`. The committed `.claude/settings.json` is only the
   *interactive* (local) allowlist; CI forces the mode in the workflow, and
   `.claude/settings.local.json` is gitignored so a personal file can't leak into CI and
   change it. (See `docs/LEARNINGS.md`.)

7. **Fork PRs fail safe.** `agent-code-review.yml` uses `pull_request` (not
   `pull_request_target`), so a PR from a fork runs **without repo secrets** — the review
   simply doesn't run rather than exposing the token to untrusted code. **Do not "fix" this
   by switching to `pull_request_target`** unless you fully understand the risk (see below).
   `agent-pr-feedback.yml` likewise refuses fork PRs outright: the job token can't push to
   another account's branch, so it says so and stops instead of spending tokens first.

8. **Untrusted text never reaches a shell.** Issue titles, comment bodies, and review text
   are passed to the agent CLIs through environment variables and stdin, never interpolated
   into a command line. They are still *instructions to the agent* — see prompt injection
   below — but they can't become shell commands on the runner.

---

## Recommended hardening (by risk level)

**Everyone:**

- **Keep actions up to date.** `.github/dependabot.yml` (included) opens weekly PRs for the
  GitHub Actions you depend on. For stricter supply-chain control, **pin third-party
  actions to a commit SHA** instead of a tag (`uses: actions/checkout@<sha>`); Dependabot
  still bumps pinned SHAs.
- **Protect `main`.** Require a pull request and at least one **human review** before merge,
  and require status checks. The agent opens PRs; a human must approve and merge.
- **Enable native GitHub security:** secret scanning + **push protection**, Dependabot
  alerts, and (for code) CodeQL. These catch a leaked secret or a known-vuln dependency the
  agent might introduce.
- **Set a spend cap with your model provider** (Anthropic, OpenAI, or Google) on the account
  behind the key, so a misfire can't run up an unbounded bill (see `docs/COST.md`).

**Public repos / larger teams:**

- **Turn on the built-in approval gate (already wired).** The write-capable jobs
  (`agent-ready-trigger`, `plan-approval-gate`, `agent-pr-feedback`) declare
  `environment: ${{ vars.AGENT_ENVIRONMENT || 'agent' }}`. It is **off by default** — the
  environment has no protection rules, so jobs run immediately. To require human sign-off
  before any agent run, go to **Settings → Environments → `agent` → Required reviewers**
  and add the people allowed to authorize runs. The run then pauses until one of them
  approves it in the Actions UI — a strong, native "are we sure?" gate on top of the
  permission check, and it guards the secret too. Rename the environment with the
  `AGENT_ENVIRONMENT` repo variable. (Required reviewers need a public repo or a paid plan;
  on a private free-plan repo the gate can't be enabled, but the default is harmless.)
  Note: the gate is job-level, so an unauthorized `@agent` comment will create a *pending*
  approval request that the permission check would otherwise have rejected — just decline it.
- **Restrict who holds write access.** Since write access = ability to trigger the agent,
  treat the collaborator list as a security boundary. Prefer teams over individual grants.
- **Trim the agent's tool surface.** The agent runs in full-auto mode in CI; if
  exfiltration via outbound HTTP is a concern, narrow what it can reach. On Claude, edit
  `.claude/settings.json` (e.g. drop `Bash(curl *)`) and/or add `--disallowedTools` to the
  `claude_args` in `.github/actions/agent-run/action.yml`. On Codex, swap
  `--dangerously-bypass-approvals-and-sandbox` for `--sandbox workspace-write` in that same
  file; on Gemini, replace `--yolo` with a narrower `--approval-mode`. Trade-off: some
  legitimate tasks need network and tooling, and a narrower sandbox means more runs that
  stop half-finished.
- **Don't review untrusted fork PRs with secrets.** If you want fork PRs reviewed, do it in
  a **two-workflow split**: a `pull_request` workflow (no secrets) uploads the diff as an
  artifact; a separate trusted workflow consumes it. Never run agent code from a fork in a
  `pull_request_target` context with write permissions.

---

## Threats this model assumes you accept

- **A trusted collaborator can misuse the agent.** The controls stop *outsiders*, not a
  malicious or compromised insider with write access. Protect accounts with 2FA; review the
  agent's PRs like any other.
- **Prompt injection from repo content.** The agent reads files, issues, and PRs as part of
  its job; crafted content could try to redirect it. The human merge gate + read-only review
  token + scoped secrets bound the blast radius, but review agent output before trusting it.

---

## Reporting a vulnerability

If you find a security issue in this toolkit, please open a private report via GitHub
Security Advisories (Security → Report a vulnerability) rather than a public issue.
