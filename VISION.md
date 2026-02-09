# Ralph Tool — Vision & Improvements

## Guiding Principle

Ralph should be the fastest way to go from "I have an idea" to "Claude is building it." Install once, init in any project, and start working — whether that's planning tasks interactively, running automated implementation loops, or just having better Claude conversations with pre-built role contexts.

---

## 1. Roles System (copied to project on `ralph init`)

### The Problem
Right now, to get Claude to do anything useful (plan tasks, analyze code, review a PR), you have to explain what you want in the prompt every time. There's no reusable "persona" or instruction set.

### The Solution
Ship a `.ralph/roles/` directory with pre-built role files that users can `@`-reference in Claude Code conversations.

```
.ralph/roles/
├── ralph-plan.md          # Task planner — breaks high-level requirements into features/tasks
├── ralph-analyze.md       # Codebase analyzer — deep dive into architecture, patterns, debt
├── ralph-spec.md          # Spec writer — creates detailed task specs from requirements
├── ralph-review.md        # Code reviewer — reviews changes with context
├── ralph-test.md          # Test writer — generates test cases from specs
└── ralph-architect.md     # System architect — designs solutions before implementation
```

**Usage in Claude Code:**
```
> @ralph-plan I need to add user authentication with OAuth2 and session management
> @ralph-spec Write a spec for task 3 in the auth feature
> @ralph-analyze What patterns does this codebase use for data fetching?
```

Each role file contains:
- Clear persona definition and boundaries
- Instructions for output format (e.g., ralph-plan outputs valid prd.json entries)
- References to project files it should read
- Rules for what it should/shouldn't do

**Key detail:** These get copied to the user's project on `ralph init`, so users can customize them. The defaults should be good enough that most people never need to edit them.

---

## 2. `ralph plan` Command

### The Problem
Before you can run `ralph loop`, you need a filled `prd.json` with features and tasks, and ideally spec files for each task. Right now this is fully manual — the user writes everything by hand.

### The Solution
A new command: `ralph plan`

```
ralph plan "Add user authentication with OAuth2, role-based access control, and session management"
```

This runs a **planning loop** (similar to the implementation loop but with a different prompt) where Claude:
1. Reads the project's README.md and codebase structure
2. Breaks the high-level requirement into features and tasks
3. Writes `prd.json` entries
4. Generates spec files for each task in `1_new_tasks/`
5. Updates `testing-harness.md` if the project's test setup needs changes

Could also work interactively:
```
ralph plan --interactive
# Opens a Claude conversation with the @ralph-plan role pre-loaded
# User describes what they want, Claude asks clarifying questions
# End result: populated prd.json + spec files
```

**Iterations for planning:**
- Each iteration refines the plan (not implements code)
- Iteration 1: High-level feature breakdown
- Iteration 2: Task decomposition per feature
- Iteration 3: Spec file generation with implementation details
- Could use `--max` to control depth

---

## 3. Configurable Behaviors (ralph config / settings)

### The Problem
Some behaviors are hardcoded but should be optional depending on context:
- Auto PR creation after each feature (bad for brand new projects, good for existing codebases)
- Auto git commit (sometimes you want code local-only)
- Which files Claude should always read at start of each iteration
- Feature branch naming convention

### The Solution
A `.ralph/config/settings.json` (or section in an existing config) with toggleable behaviors:

```json
{
  "git": {
    "auto_commit": true,
    "auto_pr": true,
    "branch_prefix": "RALPH-DID",
    "exclude_from_commit": [".ralph/"]
  },
  "loop": {
    "default_model": "claude-sonnet-4-5",
    "default_max_iterations": 6,
    "context_files": ["README.md"],
    "auto_check_feature_completion": true
  },
  "review": {
    "auto_merge": false,
    "merge_strategy": "squash"
  }
}
```

**Presets** could simplify this further:
- `ralph init --preset greenfield` → git off, no PRs, just build
- `ralph init --preset existing` → git on, PRs on, conservative
- `ralph init --preset solo` → no PRs, auto-commit, fast iteration

---

## 4. Better Init Experience

### Current
`ralph init` copies templates and says "edit these 3 files." User is left staring at an empty `prd.json`.

### Improved
After copying templates, offer to run a guided setup:
```
ralph init
# Creates .ralph/...
# "Would you like to set up your project now? (y/N)"
# If yes: runs ralph plan --interactive to populate tasks
# Also detects project type and pre-fills testing-harness.md:
#   - Found package.json → npm run build, npm test
#   - Found Cargo.toml → cargo build, cargo test
#   - Found go.mod → go build, go test
```

---

## 5. Task Context Files (`_CONTEXT.md`, `_TASK_INDEX.md`)

### Learned from Usage
In hellskitchen-app, these patterns emerged naturally:
- `_CONTEXT.md` — shared context that ALL tasks in a feature need (tech stack, conventions, file locations)
- `_TASK_INDEX.md` — execution order, phases (parallel vs sequential), file coverage map

### Formalize This
- Add `_CONTEXT.md` template to `feature-spec-template.md` guidance
- Add support in the orchestrator prompt to auto-read `_CONTEXT.md` if it exists alongside task specs
- `ralph plan` should generate these automatically when creating multi-task features

---

## 6. `ralph add` — Quick Task Addition

```
ralph add "Fix the login button not redirecting after OAuth callback"
ralph add --feature auth "Add remember me checkbox"
```

Appends a task to `prd.json` without opening the file. For quick additions during development. Could optionally auto-generate a spec file stub.

---

## 7. `ralph dashboard` / Better Status

Current `ralph status` is text-based. Could be improved:
- Show total project progress (features done / total)
- Show cost spent so far (sum across all iterations)
- Show time per task (from log timestamps)
- Show AGENT.md learnings summary
- Optionally: web UI (`ralph dashboard --web`) for a richer view

---

## 8. Plugin / Hook System

Let users extend Ralph's behavior at key points:
- `on_task_complete` — run custom script after each task (e.g., deploy preview, notify Slack)
- `on_feature_complete` — run custom script after feature done (e.g., run full test suite)
- `on_iteration_start` — inject extra context or setup
- `on_stuck` — custom recovery logic before giving up

Configured in `settings.json`:
```json
{
  "hooks": {
    "on_task_complete": "scripts/notify.sh",
    "on_feature_complete": "npm run test:e2e"
  }
}
```

---

## 9. Multi-Model Strategy

Allow different models for different phases:
```json
{
  "models": {
    "plan": "claude-opus-4-5",
    "implement": "claude-sonnet-4-5",
    "review": "claude-opus-4-5",
    "explore": "claude-haiku-3"
  }
}
```

Planning and review benefit from stronger models. Implementation and exploration can use faster/cheaper ones.

---

## 10. Resume / Recovery

### The Problem
If Ralph gets stuck or max iterations hit, you manually fix things and restart. There's no concept of "resume from where you left off."

### The Solution
- `ralph resume` — continues the loop from the last incomplete task
- Reads the last `progress.txt` and `AGENT.md` to reconstruct context
- Useful after manual fixes or after adding budget (more iterations)

---

## 11. Template Library

Ship optional templates for common project types:
```
ralph init --template nextjs
ralph init --template react-native
ralph init --template express-api
```

Each template pre-fills:
- `testing-harness.md` with the right build/test commands
- `prompt.md` with framework-specific orchestrator hints
- `AGENT.md` with known patterns for that framework

---

## 12. Cost Budgets

```json
{
  "budget": {
    "max_cost_per_feature": 5.00,
    "max_cost_per_task": 2.00,
    "warn_at": 0.80
  }
}
```

Loop script checks cost after each iteration and pauses if budget exceeded. Prevents runaway spending on stuck tasks.

---

## Priority Order

What to build first (impact vs effort):

1. **Roles system** — low effort, high impact, improves UX for everyone immediately
2. **Configurable git/PR behavior** — low effort, removes friction for new projects
3. **`ralph plan` command** — medium effort, huge impact, closes the biggest UX gap
4. **Better init** (auto-detect stack, guided setup) — medium effort, good first impression
5. **Task context files** (formalize `_CONTEXT.md`) — low effort, learned from real usage
6. **`ralph add`** — low effort, convenience
7. **Cost budgets** — low effort, safety net
8. **Everything else** — higher effort, iterate based on usage
