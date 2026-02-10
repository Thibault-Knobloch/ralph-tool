# Ralph

AI-powered task automation for software development. Ralph orchestrates [Claude Code](https://docs.anthropic.com/en/docs/claude-code) to implement features task-by-task — one task per iteration, fresh context every time, automatic PRs when done.

## Install

```bash
npm install -g ralph-tool
```

> Ralph auto-installs required dependencies (`jq`, `bc`, `claude`) during setup. Docker and `gh` are optional.

## Quick Start

```bash
cd my-project
ralph init
```

This creates a `.ralph/` directory with all config, templates, and task files. Then choose your workflow:

### Workflow A: Plan from Vision

Best for greenfield projects or large feature sets. Define what you want, let Ralph plan the tasks.

```bash
# 1. Write your project vision (or use the Claude Code role to help)
#    Edit .ralph/config/vision.md

# 2. Ralph plans features + creates task specs from your vision
ralph plan --max 20

# 3. Ralph implements everything
ralph start --max 50

# 4. Review & merge PRs as they come
ralph review
```

### Workflow B: Define Tasks Directly

Best for adding specific features to an existing project.

```bash
# 1. Edit .ralph/tasks/prd.json with your features and tasks
#    Optionally create spec files in .ralph/tasks/1_new_tasks/

# 2. Configure build/test commands
#    Edit .ralph/tasks/testing-harness.md

# 3. Run it
ralph start --max 10
```

## Commands

| Command | Description |
|---------|-------------|
| `ralph init` | Initialize Ralph in current directory |
| `ralph start [options]` | Run loop in Docker sandbox (recommended) |
| `ralph loop [options]` | Run loop directly on your machine |
| `ralph plan [options]` | Plan features from `vision.md` into tasks |
| `ralph sandbox` | Open interactive Docker shell |
| `ralph status` | Show current feature and task progress |
| `ralph review` | Review latest PR and merge to main |
| `ralph cleanup [feature]` | Archive completed features |
| `ralph clear` | Clear iteration logs |

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--max N` | 6 (start/loop), 10 (plan) | Maximum iterations |
| `--model MODEL` | sonnet | Model to use: `sonnet`, `opus`, `haiku` |
| `--local` | off | Commit locally only, skip branch/push/PR |

## How It Works

**Loop mode** (`start` / `loop`):

1. Ralph picks the next incomplete task from `prd.json`
2. Reads the task spec (if one exists) and delegates code exploration to subagents
3. Implements the code changes, then runs your test harness
4. On pass: marks task complete, updates progress. On fail: fixes and retests
5. When all tasks in a feature are done → creates a git branch and PR automatically
6. Repeat. Each iteration gets fresh context — state lives in files, not memory

**Plan mode** (`plan`):

1. Reads your `vision.md` and existing `prd.json`
2. Identifies one unplanned area, explores the codebase
3. Creates a detailed spec file and adds the feature + tasks to `prd.json`
4. Every 5 iterations: runs a cleanup pass to consolidate and reorder
5. Repeat until the vision is fully covered

## Claude Code Roles

Ralph ships with roles you can use directly in Claude Code (`@` mention the file):

| Role | File | Purpose |
|------|------|---------|
| Vision Creator | `.ralph/roles/ralph-plan-vision.md` | Helps you write `vision.md` interactively |
| Feature Planner | `.ralph/roles/ralph-plan-feature.md` | Plans a single feature with you |
| Helper | `.ralph/roles/ralph-helper.md` | Explains Ralph concepts and usage |

## Project Structure

After `ralph init`:

```
.ralph/
├── config/
│   ├── prompt.md               # Loop orchestrator prompt
│   ├── plan-prompt.md          # Planning orchestrator prompt
│   ├── plan-cleanup-prompt.md  # Planning cleanup prompt
│   ├── AGENT.md                # Persistent learnings (accumulates over time)
│   ├── vision.md               # Your project vision (for plan mode)
│   └── pr-review-prompt.md     # PR review template
├── tasks/
│   ├── prd.json                # Features and tasks definition
│   ├── progress.txt            # Current iteration progress
│   ├── testing-harness.md      # Build/test commands
│   ├── feature-spec-template.md
│   ├── 1_new_tasks/            # Active task spec files
│   └── 2_done_tasks/           # Archived completed features
├── roles/                      # Claude Code role files
└── logs/                       # Iteration logs and cost tracking
```

## Key Concepts

- **One task per iteration** — Ralph completes exactly one task, then exits. The loop script starts a new iteration with fresh context.
- **File-based state** — All state lives in `prd.json`, `progress.txt`, and `AGENT.md`. No memory between iterations.
- **AGENT.md** — Persistent knowledge base that accumulates learnings across all iterations and features. Never cleared automatically.
- **Spec files** — Detailed implementation specs in `1_new_tasks/`. Created by `ralph plan` or manually.
- **Testing harness** — Your build/test commands in `testing-harness.md`. Ralph runs these after every implementation.

## Requirements

- **Node.js** 18+
- **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
- **Docker** — for `ralph start` / `ralph sandbox` (optional if using `ralph loop`)
- **GitHub CLI** (`gh`) — for PR creation and `ralph review` (optional with `--local`)
- **jq**, **bc** — auto-installed during `npm install`

## License

MIT
