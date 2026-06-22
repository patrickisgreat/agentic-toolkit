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
   the `agent-ready` label, approves a high-complexity plan (`/approve-plan`), or comments
   `@claude`. **The agent never merges its own PR** — a human owns the merge.

2. **Write/admin permission gates.** `claude-pr-feedback.yml` and `plan-approval-gate.yml`
   check the commenter's repo permission level and **refuse anyone below write/admin**.
   This is what stops a random account on a public repo from driving the agent via
   `@claude …` or `/approve-plan`.

3. **No silent auto-trigger.** `auto-label-agent-ready.yml` is comment-only — it never
   applies the label (and couldn't usefully: a `GITHUB_TOKEN`-applied label doesn't fire
   the trigger). A human deliberately starts every run.

4. **Least-privilege job tokens.** Each workflow declares the minimum `permissions:` it
   needs. The **review job is `contents: read`** — even if its prompt were subverted, the
   job token can't push code. Only the implementation jobs get `contents: write`, and only
   because they must create a branch and PR.

5. **Scoped secret exposure.** The only secret handed to the agent is
   `CLAUDE_CODE_OAUTH_TOKEN`. No cloud keys, deploy creds, or other secrets are placed in
   the agent's environment by these workflows.

6. **`bypassPermissions` is confined to ephemeral CI runners** with a repo-scoped token —
   not a developer laptop. The committed `.claude/settings.json` is only the *interactive*
   (local) allowlist; CI forces the permission mode in the workflow. `.claude/settings.local.json`
   is gitignored so a personal file can't leak into CI and change the mode. (See
   `docs/LEARNINGS.md`.)

7. **Fork PRs fail safe.** `claude-code-review.yml` uses `pull_request` (not
   `pull_request_target`), so a PR from a fork runs **without repo secrets** — the review
   simply doesn't run rather than exposing the token to untrusted code. **Do not "fix" this
   by switching to `pull_request_target`** unless you fully understand the risk (see below).

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
- **Set an Anthropic spend cap** on the account behind the token, so a misfire can't run up
  an unbounded bill (see `docs/COST.md`).

**Public repos / larger teams:**

- **Gate the agent behind a GitHub Environment with required reviewers.** Add
  `environment: agent` to the agent jobs and configure required reviewers on that
  environment — the run pauses for human approval before it can use the secret. A strong,
  native "are we sure?" gate on top of the permission check.
- **Restrict who holds write access.** Since write access = ability to trigger the agent,
  treat the collaborator list as a security boundary. Prefer teams over individual grants.
- **Trim the agent's tool surface.** The agent runs under `bypassPermissions` in CI; if
  exfiltration via outbound HTTP is a concern, narrow `.claude/settings.json` (e.g. drop
  `Bash(curl *)`) and/or pass `--disallowedTools` so a subverted prompt has fewer
  primitives. Trade-off: some legitimate tasks need network/tooling.
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
