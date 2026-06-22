# Cost containment & reporting

Running agents in CI spends money two ways: **runner minutes** (GitHub Actions compute)
and **LLM tokens** (the model calls). This toolkit is built so an org can dial both up or
down to fit its budget, and can measure what it's spending over time.

Everything here is adjustable via **repository variables** (Settings → Secrets and
variables → Variables) — no file edits required.

---

## The knobs

| Variable | Applies to | Default | What it does |
| --- | --- | --- | --- |
| `AGENT_MODEL` | implement, PR feedback, retro | `sonnet` | Model for the common, frequent jobs. Drop to `haiku` to cut cost, raise to `opus` for hardest work. |
| `AGENT_PLAN_MODEL` | high-complexity planning | `opus` | Planning is rare and high-leverage (a bad plan wastes a whole implementation), so it defaults to the strongest model. Lower it on a tight budget. |
| `AGENT_REVIEW_MODEL` | PR review | `sonnet` | `haiku` = cheap/light, `sonnet` = balanced, `opus` = deepest. |
| `AGENT_MAX_TURNS` | all Claude jobs | _(unset)_ | Hard cap on agent loop iterations. Bounds a runaway run. Leave unset for no cap; set e.g. `40` to contain worst case. |
| `ENABLE_CLAUDE_REVIEW` | PR review | _(off)_ | The review workflow only runs when this is `true`. Off by default — you don't pay for review until you opt in. |
| `RUNNER_COST_PER_MIN` | cost report | `0` | USD per runner-minute for the report's runner-cost line. `0` for public repos (free); ~`0.008` for private `ubuntu-latest`. |
| `LLM_COST_PER_RUN_JSON` | cost report | _(built-in)_ | JSON map of workflow file → average USD/run, to calibrate the report's LLM estimate against your actuals. |

Model names accept the tier **aliases** `haiku` / `sonnet` / `opus` (resolve to the latest
of each tier) or a pinned full model ID (e.g. `claude-sonnet-4-6`) for reproducibility.

### Model strategy (the biggest lever)

Token cost dwarfs runner cost, and model tier dominates token cost. The defaults encode a
sensible split:

- **Frequent, well-scoped work → `sonnet`** (implement / feedback / retro). Good quality,
  much cheaper than Opus.
- **Rare, high-stakes work → `opus`** (planning). You're paying for a good plan once.
- **Review → `sonnet`**, or `haiku` if you just want a cheap sanity pass.

Tightest budget? Set `AGENT_MODEL=haiku`, `AGENT_PLAN_MODEL=sonnet`, leave review off.
Quality over cost? `AGENT_MODEL=sonnet`, `AGENT_PLAN_MODEL=opus`, `AGENT_REVIEW_MODEL=opus`.

### Other built-in containment

These are baked into the workflows, no config needed:

- **Label-gated execution.** The agent only runs on issues a human deliberately labels —
  nothing fires automatically.
- **Review is opt-in** and **skips drafts and docs-only PRs** (`paths-ignore`).
- **Concurrency cancel** on review: a new push cancels the in-flight review, so rapid
  pushes don't stack up paid runs.
- **`timeout-minutes`** on every job caps wall-clock (and thus runner minutes).
- **The retro only runs on agent PRs that show signs of needing correction** — a clean
  merge spends nothing.

---

## Preset profiles

Pick a starting point, then tune:

**Solo / hobby (minimize spend)**
```
AGENT_MODEL=haiku
AGENT_PLAN_MODEL=sonnet
AGENT_MAX_TURNS=30
ENABLE_CLAUDE_REVIEW=    (leave off)
```

**Team (balanced — recommended default)**
```
AGENT_MODEL=sonnet
AGENT_PLAN_MODEL=opus
ENABLE_CLAUDE_REVIEW=true
AGENT_REVIEW_MODEL=sonnet
```

**Quality-first (cost is not the constraint)**
```
AGENT_MODEL=sonnet
AGENT_PLAN_MODEL=opus
ENABLE_CLAUDE_REVIEW=true
AGENT_REVIEW_MODEL=opus
```

---

## Measuring spend: the cost report

`/.github/workflows/cost-report.yml` produces a **Markdown cost report** over a window:
per-workflow run counts, durations, success/failure rates, runner-minute cost, and an
LLM-cost estimate — with **period-over-period trend**.

- **Schedule:** monthly (1st, 06:00 UTC).
- **On demand:** Actions → **Agentic Cost Report** → Run workflow. Inputs:
  - `days` — window to analyze (default 30).
  - `commit_report` — commit a dated file to `docs/cost-reports/`.
  - `open_issue` — open a tracking issue with the report.
- **Output:** always written to the run's **job summary**; optionally committed and/or
  filed as an issue.

### How accurate is it?

- **Runner minutes and run counts are exact** — straight from the GitHub Actions API.
- **LLM cost is an estimate.** GitHub exposes run *timing*, not *tokens*, so the report
  multiplies run counts by an average USD/run per workflow. The built-in averages are
  rough starting points; **calibrate them** with `LLM_COST_PER_RUN_JSON` once you've seen
  a few real bills. Example:
  ```
  LLM_COST_PER_RUN_JSON = {"claude-code-review.yml":0.10,"agent-ready-trigger.yml":0.80}
  ```

### Getting exact token cost

For ground truth, use **Anthropic's usage/cost reporting** in the
[Console](https://console.anthropic.com/) (or the Admin Cost API) for the account behind
`CLAUDE_CODE_OAUTH_TOKEN`. That's the authoritative number; the report's estimate is for
trend-watching and per-workflow attribution between bills.

**Optional — real per-run tokens.** The `claude-code-action` reports token usage for each
run (visible in its job summary). To feed exact numbers into the report instead of
estimates, capture each run's usage as an artifact and have the report sum them. The
report is structured to adopt this later; the GitHub run data above needs zero setup and
is always available.
