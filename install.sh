#!/usr/bin/env bash
#
# install.sh — drop the agentic-toolkit layer into an existing repository.
#
# Usage:
#   ./install.sh [TARGET_DIR] [--force]
#
#   TARGET_DIR   Repo to install into (default: current directory).
#   --force      Overwrite toolkit-owned files that already exist
#                (workflows, templates, LABELS.yml, .claude/settings.json).
#                Never overwrites your CLAUDE.md or an existing docs/LEARNINGS.md.
#
# What it copies:
#   .github/workflows/{agent-ready-trigger,plan-approval-gate,claude-pr-feedback,
#                      agent-retro,auto-label-agent-ready,setup-labels}.yml
#   .github/ISSUE_TEMPLATE/agent-ready.md
#   .github/PULL_REQUEST_TEMPLATE/agent-generated.md
#   .github/LABELS.yml
#   .claude/settings.json
#   docs/AGENTIC_DEVELOPMENT.md
#   docs/LEARNINGS.md            (only if you don't already have one)
#   docs/plans/.gitkeep
#   CLAUDE.template.md  ->  CLAUDE.md   (only if you don't already have CLAUDE.md)
#   .gitignore                  (appends the settings.local.json rule if missing)
#
# Idempotent: re-running skips files that already exist (unless --force).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parse args ───────────────────────────────────────────────────────────────
TARGET="."
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "error: unknown flag: $arg" >&2; exit 2 ;;
    *) TARGET="$arg" ;;
  esac
done

TARGET="$(cd "$TARGET" 2>/dev/null && pwd || true)"
if [ -z "$TARGET" ]; then
  echo "error: target directory does not exist" >&2; exit 1
fi
if [ "$TARGET" = "$SCRIPT_DIR" ]; then
  echo "error: refusing to install the toolkit into itself" >&2; exit 1
fi

echo "Installing agentic-toolkit layer into: $TARGET"
[ -d "$TARGET/.git" ] || echo "  note: $TARGET is not a git repo root — continuing anyway."
echo

copied=0 skipped=0

# copy_file <relative-src> <relative-dst> [overwritable]
#   overwritable=1 → honors --force; default 0 → never overwrite.
copy_file() {
  local rel_src="$1" rel_dst="$2" overwritable="${3:-0}"
  local src="$SCRIPT_DIR/$rel_src" dst="$TARGET/$rel_dst"
  if [ ! -f "$src" ]; then
    echo "  ! missing in toolkit: $rel_src (skipped)"; return
  fi
  if [ -f "$dst" ]; then
    if [ "$overwritable" = "1" ] && [ "$FORCE" = "1" ]; then
      : # fall through and overwrite
    else
      echo "  · exists, kept:   $rel_dst"; skipped=$((skipped+1)); return
    fi
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  + installed:      $rel_dst"; copied=$((copied+1))
}

# ── Workflows (toolkit-owned; overwritable with --force) ─────────────────────
for wf in agent-ready-trigger plan-approval-gate claude-pr-feedback \
          agent-retro claude-code-review cost-report \
          auto-label-agent-ready setup-labels; do
  copy_file ".github/workflows/$wf.yml" ".github/workflows/$wf.yml" 1
done

# ── Templates, labels, settings, deps (toolkit-owned; overwritable with --force) ─
copy_file ".github/ISSUE_TEMPLATE/agent-ready.md"            ".github/ISSUE_TEMPLATE/agent-ready.md" 1
copy_file ".github/PULL_REQUEST_TEMPLATE/agent-generated.md" ".github/PULL_REQUEST_TEMPLATE/agent-generated.md" 1
copy_file ".github/LABELS.yml"                               ".github/LABELS.yml" 1
copy_file ".github/dependabot.yml"                           ".github/dependabot.yml" 0
copy_file ".claude/settings.json"                            ".claude/settings.json" 1

# ── Docs ─────────────────────────────────────────────────────────────────────
copy_file "docs/AGENTIC_DEVELOPMENT.md" "docs/AGENTIC_DEVELOPMENT.md" 1
copy_file "docs/COST.md"                "docs/COST.md" 1
copy_file "docs/SECURITY.md"            "docs/SECURITY.md" 0
copy_file "docs/plans/.gitkeep"         "docs/plans/.gitkeep" 1
copy_file "docs/cost-reports/.gitkeep"  "docs/cost-reports/.gitkeep" 1
# Never clobber a project's own learnings.
copy_file "docs/LEARNINGS.md"           "docs/LEARNINGS.md" 0

# ── CLAUDE.md (never clobber; drop the template for reference if one exists) ──
if [ -f "$TARGET/CLAUDE.md" ]; then
  echo "  · exists, kept:   CLAUDE.md"
  copy_file "CLAUDE.template.md" "CLAUDE.template.md" 1
  echo "    → merge the 'Agentic-workflow invariants' section from CLAUDE.template.md into your CLAUDE.md."
else
  copy_file "CLAUDE.template.md" "CLAUDE.md" 0
  echo "    → fill in the <PLACEHOLDERS> in CLAUDE.md."
fi

# ── .gitignore (append the rule if missing; never overwrite) ─────────────────
GI="$TARGET/.gitignore"
IGNORE_RULE='.claude/settings.local.json'
if [ -f "$GI" ] && grep -qF "$IGNORE_RULE" "$GI"; then
  echo "  · .gitignore already ignores $IGNORE_RULE"
else
  {
    printf '\n# Per-user local Claude Code settings. Never commit: the SDK loads it as a\n'
    printf '# settings source in CI and it overrides the workflow permission mode. See docs/LEARNINGS.md.\n'
    printf '%s\n' "$IGNORE_RULE"
  } >> "$GI"
  echo "  + appended $IGNORE_RULE to .gitignore"
fi

# ── Summary + next steps ─────────────────────────────────────────────────────
echo
echo "Done: $copied installed, $skipped kept."
cat <<'EOF'

Next steps:
  1. Add the provider secret:   Settings → Secrets and variables → Secrets
       CLAUDE_CODE_OAUTH_TOKEN   (for the default Claude provider)
  2. (Optional) Set AGENT_PROVIDER variable: claude | openai-codex | copilot | custom
  3. Sync labels:               Actions → Setup Labels → Run workflow
  4. Fill in CLAUDE.md (or merge CLAUDE.template.md into yours).
  5. (Optional) Cost & review variables — all have sensible defaults:
       AGENT_MODEL (sonnet)  AGENT_PLAN_MODEL (opus)  AGENT_REVIEW_MODEL (sonnet)
       AGENT_MAX_TURNS       ENABLE_CLAUDE_REVIEW=true   → see docs/COST.md
  6. Review the security posture before going live → see docs/SECURITY.md
  7. Commit the layer, open an agent-ready issue, and apply the `agent-ready` label.

See docs/AGENTIC_DEVELOPMENT.md for the full workflow.
EOF
