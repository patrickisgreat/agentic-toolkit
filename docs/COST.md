# Cost containment & reporting

Running agents in CI spends money two ways: **runner minutes** (GitHub Actions compute)
and **model tokens** (the LLM calls). This toolkit is built so an org can dial both up or
down to fit its budget, and can measure what it's spending over time.

Everything here is adjustable via **repository variables** (Settings → Secrets and
variables → Variables) — no file edits required. The knobs are provider-neutral: they work
the same whether `AGENT_PROVIDER` points at Claude, OpenAI, or Gemini.

---

## The knobs

| Variable | Applies to | Default | What it does |
| --- | --- | --- | --- |
| `AGENT_MODEL` | implement, PR feedback, retro | `sonnet` on Claude, else the CLI default | Model for the common, frequent jobs. Drop a tier to cut cost, raise it for the hardest work. |
| `AGENT_PLAN_MODEL` | high-complexity planning | `opus` on Claude, else the CLI default | Planning is rare and high-leverage (a bad plan wastes a whole implementation), so it defaults to the strongest model. Lower it on a tight budget. |
| `AGENT_REVIEW_MODEL` | PR review | `sonnet` on Claude, else the CLI default | `haiku` = cheap/light, `sonnet` = balanced, `opus` = deepest. |
| `AGENT_MAX_TURNS` | Claude and Gemini jobs | _(unset)_ | Hard cap on agent loop iterations. Bounds a runaway run. Leave unset for no cap; set e.g. `40` to contain worst case. Codex has no turn cap — `timeout-minutes` bounds it instead. |
| `ENABLE_AGENT_REVIEW` | PR review | _(off)_ | The review workflow only runs when this is `true`. Off by default — you don't pay for review until you opt in. (`ENABLE_CLAUDE_REVIEW` still works.) |
| `RUNNER_COST_PER_MIN` | cost report | `0` | USD per runner-minute for the report's runner-cost line. `0` for public repos (free); ~`0.008` for private `ubuntu-latest`. |
| `LLM_COST_PER_RUN_JSON` | cost report | _(built-in)_ | JSON map of workflow file → average USD/run, to calibrate the report's LLM estimate against your actuals. |

### Model names, per provider

The three model variables are provider-neutral: whatever you put in them is handed to the
agent you've selected with `AGENT_PROVIDER`.

- **Claude** accepts the tier **aliases** `haiku` / `sonnet` / `opus` (each resolves to the
  latest of its tier) or a pinned full model ID (e.g. `claude-sonnet-4-6`) for
  reproducibility. These are what the defaults above encode.
- **OpenAI Codex** and **Gemini** take their own model IDs (e.g. `gpt-5-codex`,
  `gemini-2.5-flash`). Leave the variable **unset** and the toolkit passes no `--model` at
  all, so the CLI uses its current default — that way a model rename upstream can't break
  your repo. Set one explicitly when you want a specific cost/quality point or a pin.

### Model strategy (the biggest lever)

Token cost dwarfs runner cost, and model tier dominates token cost. The Claude defaults
encode a split that transfers to any provider:

- **Frequent, well-scoped work → mid tier** (implement / feedback / retro). Good quality,
  a fraction of the flagship price.
- **Rare, high-stakes work → top tier** (planning). You pay for a good plan once, and a
  bad plan wastes a whole implementation.
- **Review → mid tier**, or the cheapest tier if you just want a sanity pass.

Tightest budget? Set `AGENT_MODEL=haiku`, `AGENT_PLAN_MODEL=sonnet`, leave review off.
Quality over cost? `AGENT_MODEL=sonnet`, `AGENT_PLAN_MODEL=opus`, `AGENT_REVIEW_MODEL=opus`.
On OpenAI or Gemini, substitute that provider's equivalent tiers.

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

Model names below are Claude tiers; on another provider use its equivalents.

**Solo / hobby (minimize spend)**
```
AGENT_MODEL=haiku
AGENT_PLAN_MODEL=sonnet
AGENT_MAX_TURNS=30
ENABLE_AGENT_REVIEW=     (leave off)
```

**Team (balanced — recommended default)**
```
AGENT_MODEL=sonnet
AGENT_PLAN_MODEL=opus
ENABLE_AGENT_REVIEW=true
AGENT_REVIEW_MODEL=sonnet
```

**Quality-first (cost is not the constraint)**
```
AGENT_MODEL=sonnet
AGENT_PLAN_MODEL=opus
ENABLE_AGENT_REVIEW=true
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
  rough starting points calibrated for mid-tier models; **replace them** with
  `LLM_COST_PER_RUN_JSON` once you've seen a few real bills — especially on a provider
  other than Claude, where the defaults are only a shape, not a price. Example:
  ```
  LLM_COST_PER_RUN_JSON = {"agent-code-review.yml":0.10,"agent-ready-trigger.yml":0.80}
  ```

### Getting exact token cost

For ground truth, read your provider's own billing console for the account behind the
secret you configured:

| Provider | Where the authoritative number lives |
| --- | --- |
| `claude` | [Anthropic Console](https://console.anthropic.com/) usage/cost reporting, or the Admin Cost API |
| `openai` | [OpenAI platform](https://platform.openai.com/usage) usage dashboard |
| `gemini` | [Google AI Studio](https://aistudio.google.com/) / Cloud Billing for the key's project |

That's the real number; the report's estimate is for trend-watching and per-workflow
attribution between bills.

**Optional — real per-run tokens.** Each provider's CLI/action reports token usage for the
run (Claude's shows up in the action's job summary; `codex exec` and `gemini` print a usage
summary). To feed exact numbers into the report instead of estimates, capture each run's
usage as an artifact and have the report sum them. The report is structured to adopt this
later; the GitHub run data above needs zero setup and is always available.
