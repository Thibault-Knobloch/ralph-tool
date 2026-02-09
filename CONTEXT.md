# Ralph Tool — Context & Architecture

## What is Ralph

Ralph is an AI-powered task automation CLI for software development. You `npm install` it globally, run `ralph init` in any project, define features and tasks, and Ralph runs Claude in an automated loop — completing one task per iteration, tracking costs, accumulating learnings, and optionally creating PRs when features are done.

The core idea: break a project into **Features** (each with **Tasks**), give Claude a structured orchestrator prompt, and let it iterate through tasks autonomously — reading context, implementing code, running tests, updating progress, and exiting cleanly so the next iteration starts fresh.

---

## How It Works (User Flow)

```
npm install -g ralph-tool     # One-time global install
cd my-project
ralph init                     # Creates .ralph/ with config + task templates
# User edits: prd.json (tasks), testing-harness.md (build/test commands), prompt.md (optional tuning)
ralph start --max 10           # Runs loop in Docker sandbox (10 iterations max)
ralph loop --max 10            # Same but runs directly on host (no Docker)
ralph status                   # Check progress anytime
ralph review                   # Claude reviews the PR, merges it
ralph cleanup                  # Archive completed features
```

### Each Iteration (inside the loop)

1. Claude starts with **fresh context** (no memory of previous iterations)
2. Reads 3 mandatory files: `README.md`, `AGENT.md` (persistent learnings), `progress.txt` (what just happened)
3. Runs `ralph status` to identify current feature and next incomplete task
4. Reads the task's spec file (if any) for detailed requirements
5. Implements the task (delegates exploration/testing to subagents)
6. Runs quality checks via testing harness (single subagent)
7. Marks task complete in `prd.json`, updates `progress.txt` and `AGENT.md`
8. Exits — loop script detects completion, checks if feature is done
9. If feature complete → auto-creates git branch + PR, archives progress
10. Next iteration starts (or loop ends if all features done / max reached / stuck)

---

## Architecture

```
ralph-tool/                     # The npm package (engine — stays here)
├── bin/
│   └── ralph.js                # Node.js CLI entry point (commander)
├── scripts/                    # Bash scripts that do the actual work
│   ├── loop.sh                 # Main iteration engine (streams Claude, tracks cost, detects completion)
│   ├── start.sh                # Docker sandbox launcher (builds + runs docker-compose)
│   ├── sandbox.sh              # Interactive Docker shell
│   ├── status.sh               # Reads prd.json, displays current feature/task
│   ├── check_feature_completion.sh  # Auto-detects when all tasks in feature are done
│   ├── git_feature_complete.sh      # Creates branch, commits, pushes, opens PR
│   ├── review.sh               # Claude reviews PR diff, merges with squash
│   ├── clear.sh                # Deletes iteration logs (keeps progress/)
│   ├── cleanup.sh              # Archives completed features to 2_done_tasks/
│   └── postinstall.js          # Makes all .sh files executable after npm install
├── helpers/                    # Shared bash utilities sourced by scripts
│   ├── constants.sh            # MAX_CHARS, DEFAULT_MODEL, RALPH_NAMES
│   ├── display_helpers.sh      # Colors, banners, spinners, cost summaries
│   ├── cost_helpers.sh         # Model pricing tables, cost calculation
│   ├── iteration_helpers.sh    # Per-iteration cost/subagent extraction
│   ├── output_formatting.jq    # jq filter: formats Claude's JSON stream into readable output
│   └── extract_subagent_map.jq # jq filter: maps subagent IDs to sequential numbers
├── templates/                  # Copied to project on `ralph init`
│   ├── prompt.md               # Orchestrator instructions (the brain)
│   ├── AGENT.md                # Persistent knowledge base (empty starter)
│   ├── pr-review-prompt.md     # PR review template
│   ├── prd.json                # Empty feature/task structure
│   ├── testing-harness.md      # Build/test command definitions
│   └── feature-spec-template.md # Template for writing detailed task specs
├── Dockerfile                  # Node 20 + git + gh + claude-code + ripgrep + jq
├── docker-compose.yaml         # Mounts project, persists claude/gh config via volumes
├── entrypoint.sh               # SSH/git/permissions setup, runs as node user via gosu
├── package.json                # npm config, bin entry, dependencies (commander, chalk)
└── README.md
```

### What gets created in the user's project on `ralph init`

```
.ralph/                        # User-editable project config (lives in the repo)
├── config/
│   ├── prompt.md               # Orchestrator prompt — EDIT to tune Claude's behavior
│   ├── AGENT.md                # Persistent learnings — auto-updated by Claude each iteration
│   └── pr-review-prompt.md     # PR review template — EDIT to customize review style
├── tasks/
│   ├── prd.json                # Feature & task definitions — MAIN USER INPUT
│   ├── progress.txt            # Current progress — auto-updated, cleared between features
│   ├── testing-harness.md      # Build/test commands — EDIT for your project's stack
│   ├── feature-spec-template.md # Reference template for writing detailed specs
│   ├── 1_new_tasks/            # Put task spec .md files here
│   └── 2_done_tasks/           # Archived completed features (auto-moved by cleanup)
└── logs/
    ├── iter_*.raw.jsonl        # Raw Claude JSON stream per iteration
    ├── iter_*.pretty.log       # Formatted readable output per iteration
    ├── iter_*.subagent_map.json # Subagent ID mapping per iteration
    └── progress/               # Archived progress.txt files per completed feature
```

### The split: engine vs config

| Lives in npm package (engine) | Lives in user's project (config) |
|-------------------------------|----------------------------------|
| `bin/ralph.js` — CLI router | `.ralph/config/prompt.md` — orchestrator behavior |
| `scripts/*.sh` — loop, status, git, review | `.ralph/config/AGENT.md` — accumulated learnings |
| `helpers/*.sh` — display, cost, formatting | `.ralph/tasks/prd.json` — features & tasks |
| `helpers/*.jq` — output formatting | `.ralph/tasks/testing-harness.md` — build/test commands |
| `Dockerfile` + `docker-compose.yaml` | `.ralph/tasks/1_new_tasks/*.md` — task specs |
| `templates/` — starter files | `.ralph/logs/` — iteration logs |

The user never edits anything in the npm package. The package provides the engine; `.ralph/` provides the project-specific config.

---

## CLI Commands

| Command | What it does | Requires Docker |
|---------|-------------|-----------------|
| `ralph init` | Creates `.ralph/` with templates in current directory | No |
| `ralph start [--max N] [--model MODEL]` | Runs loop inside Docker sandbox | **Yes** |
| `ralph loop [--max N] [--model MODEL]` | Runs loop directly on host machine | No |
| `ralph sandbox` | Opens interactive Docker shell for manual work | **Yes** |
| `ralph status` | Shows current feature, task progress, next task | No |
| `ralph clear` | Deletes iteration logs (keeps progress/) | No |
| `ralph review` | Claude reviews latest PR diff, then merges (squash + delete branch) | No |
| `ralph cleanup [feature]` | Archives completed features to `2_done_tasks/` | No |

**Defaults:** 6 iterations max, `claude-sonnet-4-5` model.

**Docker is optional.** `ralph start` uses it for isolation (safe sandbox with SSH/git/gh forwarding). `ralph loop` runs everything directly. Both use the same loop engine underneath.

---

## Task Data Model (`prd.json`)

```json
{
  "features": [
    {
      "id": "feature-slug",
      "name": "Human-Readable Feature Name",
      "description": "What this feature does",
      "feature_completed": false,
      "tasks": [
        {
          "id": "task-slug",
          "name": "Task Name",
          "completed": false,
          "requirements": ["Requirement 1", "Requirement 2"],
          "specFile": ".ralph/tasks/1_new_tasks/task-spec.md"
        }
      ]
    }
  ]
}
```

- Features are processed **sequentially** (all tasks in Feature 1 before Feature 2)
- Tasks within a feature are picked in order (first incomplete)
- `specFile` is optional — points to a detailed markdown spec in `1_new_tasks/`
- `requirements` array provides a quick summary if no spec file

---

## Key Mechanisms

### Orchestrator Pattern
Claude acts as an orchestrator: it doesn't do everything itself. It delegates codebase exploration to subagents, delegates testing to a single subagent, and focuses on coordination and implementation. This keeps the main context clean.

### Fresh Context Per Iteration
Each iteration starts from zero. Claude has no memory of previous runs. Continuity is maintained through 3 files: `AGENT.md` (persistent learnings), `progress.txt` (what just happened), and `prd.json` (task completion state).

### Completion Detection
The loop script (`loop.sh`) detects two signals:
- `<promise>COMPLETE</promise>` — all features done
- `<promise>STUCK</promise>` — Claude is blocked, needs human help

It also pattern-matches `"Task .* completed"` + `"Exiting for next iteration"` to detect normal task completion.

### Auto Feature Completion
After each iteration, `check_feature_completion.sh` runs. If all tasks in the current feature are done, it:
1. Marks `feature_completed: true` in prd.json
2. Creates a git branch `RALPH-DID-{feature-slug}`
3. Commits all changes (excluding `.ralph/`)
4. Pushes and creates a PR with progress notes as body
5. Archives `progress.txt` to `logs/progress/`
6. Clears `progress.txt` for the next feature

### Cost Tracking
Built-in pricing for all Claude models. Per-iteration and total cost displayed in terminal. Tracks input/output/cache-read/cache-write tokens separately.

### Persistent Knowledge (AGENT.md)
Never cleared between features. Claude updates it with patterns, gotchas, and reusable code discovered during implementation. Grows over the life of the project.

---

## Dependencies

**Runtime (host):** Node.js 18+, bash, jq, bc, Claude Code CLI (`@anthropic-ai/claude-code`), GitHub CLI (`gh`) for PR features

**Runtime (Docker — used by `ralph start`):** All of the above are pre-installed in the Dockerfile, plus ripgrep, openssh-client, gosu

**npm dependencies:** commander (CLI framework), chalk (terminal colors)

---

## Origin

Ralph started as bash scripts copied between projects (culinary-cloud-mvp, hellskitchen-app). The npm package is the extraction of that system into an installable tool. The core loop, helpers, and templates are functionally identical to the original bash versions — the main difference is the Node.js CLI wrapper and the `ralph init` bootstrapping.
