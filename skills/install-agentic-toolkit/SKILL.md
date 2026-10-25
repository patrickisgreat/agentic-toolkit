---
name: install-agentic-toolkit
description: Install or refresh the agentic-toolkit GitHub Actions layer (issue → agent → PR → review → merge → retro) in a repository, then walk through provider secret, AGENT_PROVIDER variable, label sync, CLAUDE.md, and the optional cost and review knobs. Use when the user says "install the agentic toolkit", "set up the agent loop in this repo", "add the agent-ready workflow", "switch the CI agent to Codex/Gemini", or asks why a labeled issue did not trigger the agent.
---

# Install the agentic toolkit

The toolkit is a drop-in `.github/` layer plus docs, an agent guide, and the loop as skills
(installed to `.claude/skills/` for Claude Code and `.agents/skills/` for Codex and Gemini CLI). One repository
variable picks the agent (Claude Code, OpenAI Codex, or Google Gemini); everything else in
the loop is identical.

## Install

1. **Get the toolkit source.** If this skill is installed as a plugin, the toolkit lives in
   the plugin directory next to this skill (`../../install.sh`). Otherwise clone it:

   ```bash
   git clone https://github.com/patrickisgreat/agentic-toolkit /tmp/agentic-toolkit
   ```

2. **Run the installer** against the target repo from a clean working tree. It is
   idempotent: it never overwrites `CLAUDE.md` or an existing `docs/LEARNINGS.md`, appends to
   `.gitignore` rather than replacing it, and only overwrites toolkit-owned files
   (workflows, templates, labels, settings) with `--force`.

   ```bash
   /path/to/agentic-toolkit/install.sh /path/to/target-repo          # first install
   /path/to/agentic-toolkit/install.sh /path/to/target-repo --force  # refresh toolkit-owned files
   ```

   Review the summary it prints. Files marked "exists, kept" were not touched.
3. **Review the diff** with the user before committing. The layer grants a CI agent write
   access off a label; they should see what they are adopting.

## Configure (the installer cannot do these)

Walk the user through each, and run the `gh` commands when they agree:

1. **Provider secret**, under Settings → Secrets and variables → Secrets:

   | `AGENT_PROVIDER` | Secret |
   | --- | --- |
   | `claude` (default, unset means this) | `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`) or `ANTHROPIC_API_KEY` |
   | `openai` | `OPENAI_API_KEY` |
   | `gemini` | `GEMINI_API_KEY` |
   | `custom` | none; emits a `repository_dispatch` event for a listener the user writes |

   Never paste a secret into the conversation or a file. Have the user run
   `gh secret set <NAME>` themselves, or set it in the UI.
2. **`AGENT_PROVIDER` variable**, unless they want Claude:
   `gh variable set AGENT_PROVIDER --body openai`
3. **Sync labels** once: Actions → Setup Labels → Run workflow, or
   `gh workflow run setup-labels.yml`.
4. **Write `CLAUDE.md`.** Use the `write-agent-guide` skill. This is the biggest lever on
   output quality.
5. **Optional knobs**, all with sensible defaults: `AGENT_MODEL`, `AGENT_PLAN_MODEL`,
   `AGENT_REVIEW_MODEL`, `AGENT_MAX_TURNS`, and `ENABLE_AGENT_REVIEW=true` to turn on the
   automated PR review. See `docs/COST.md` in the installed repo.
6. **Security posture.** Point the user at `docs/SECURITY.md` before going live: branch
   protection, who can apply `agent-ready`, and that full-auto mode runs only on ephemeral
   CI runners.
7. **Smoke test.** Open an issue with the Agent-Ready Task template, apply `agent-ready` by
   hand, and watch the Actions tab.

## Troubleshooting a run that did not fire or did not open a PR

Check these in order; each is a known failure mode recorded in `docs/LEARNINGS.md`:

- **Label applied by automation.** A label set with the default `GITHUB_TOKEN` emits no
  `labeled` event. Remove and re-add it by hand, or use a PAT.
- **Missing provider secret.** The run reports failure and comments on the issue.
- **`.claude/settings.local.json` committed.** It overrides the workflow's permission mode
  and the agent stalls on a tool approval nobody can answer. Delete it from git; it is
  gitignored by the installer.
- **Old `claude-*.yml` workflows still present.** The installer removes the pre-rename
  `claude-pr-feedback.yml` and `claude-code-review.yml`; if they came back, two agents run
  on every event.
- **Fork PR.** Feedback and review do not run with secrets on fork PRs; that is deliberate.
