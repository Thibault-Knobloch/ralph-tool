# Ralph Tool

AI-powered task automation CLI for software development. Ralph orchestrates Claude to implement features task-by-task with automatic PR creation.

## Installation

```bash
# Install globally
npm install -g ralph-tool

# Or install from source
git clone https://github.com/Thibault-Knobloch/ralph-tool.git
cd ralph-tool
npm install -g .
```

## Quick Start

```bash
# Navigate to your project
cd my-project

# Initialize Ralph
ralph init

# Edit your configuration
# - .ralph/config/prompt.md      # AI instructions
# - .ralph/tasks/testing-harness.md  # Build/test commands
# - .ralph/tasks/prd.json        # Your tasks

# Start Ralph
ralph start
```

## Commands

| Command | Description |
|---------|-------------|
| `ralph init` | Initialize Ralph in current directory (creates .ralph/) |
| `ralph start [--max N] [--model MODEL]` | Start loop in Docker sandbox |
| `ralph sandbox` | Open interactive Docker shell |
| `ralph loop [--max N] [--model MODEL]` | Run loop directly (outside Docker) |
| `ralph status` | Check current task status |
| `ralph clear` | Clear iteration logs |
| `ralph review` | Review and merge latest PR |
| `ralph cleanup [feature]` | Archive completed features |

## Options

- `--max N` - Maximum iterations (default: 6)
- `--model MODEL` - AI model: sonnet, opus, haiku (default: sonnet)

## Project Structure After Init

```
your-project/
├── .ralph/
│   ├── config/
│   │   ├── prompt.md           # AI orchestrator instructions
│   │   ├── AGENT.md            # Accumulated learnings
│   │   └── pr-review-prompt.md # PR review template
│   ├── tasks/
│   │   ├── prd.json            # Task definitions
│   │   ├── progress.txt        # Current progress
│   │   ├── testing-harness.md  # Build/test commands
│   │   ├── feature-spec-template.md
│   │   ├── 1_new_tasks/        # Active task specs
│   │   └── 2_done_tasks/       # Archived completed tasks
│   └── logs/
│       └── progress/           # Archived progress files
└── ... (your project files)
```

## How It Works

1. **Define Tasks**: Add features and tasks to `.ralph/tasks/prd.json`
2. **Start Loop**: Run `ralph start` to begin automated implementation
3. **One Task Per Iteration**: Ralph completes exactly ONE task per loop iteration
4. **Fresh Context**: Each iteration starts with clean context (no memory)
5. **Auto PR**: When all tasks in a feature complete, Ralph creates a PR
6. **Review & Merge**: Use `ralph review` to merge and continue

## Requirements

- Node.js 18+
- Docker (for sandbox mode)
- Claude CLI (`npm install -g @anthropic-ai/claude-code`)
- GitHub CLI (`gh`) for PR operations

## License

MIT
