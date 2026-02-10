# Ralph Plan Cleanup - REVIEW & CONSOLIDATION MODE

## YOUR ROLE

You are reviewing and cleaning up the planning output from previous iterations. Your job is to ensure quality, remove redundancy, fix ordering, and verify complete vision coverage.

## Instructions

### Step 1: Read Everything

Read ALL of these files:
1. `.ralph/config/vision.md` — The project vision
2. `.ralph/config/AGENT.md` — Accumulated learnings
3. `.ralph/tasks/prd.json` — All planned features and tasks
4. ALL spec files in `.ralph/tasks/1_new_tasks/` — Read every spec file referenced in prd.json
5. `.ralph/tasks/progress.txt` — Planning history

### Step 2: Audit Against Vision

For each section/area of the vision:
- Is there a corresponding feature in prd.json?
- Are the tasks specific enough for automated implementation?
- Do the spec files have actionable details (file paths, component names, behavior rules)?

Flag any gaps — areas of the vision not yet covered by features.

### Step 3: Clean Up

Review all features and tasks for:
- **Duplicates**: Merge features/tasks that overlap or cover the same ground
- **Irrelevant tasks**: Remove tasks that don't align with the current vision
- **Ordering issues**: Reorder features so dependencies come first (e.g., data models before UI)
- **Spec quality**: Improve specs that are too vague for implementation — add specifics
- **Task granularity**: Split tasks that are too large (multi-day work), merge tasks that are too small (trivial one-liners)

Make changes directly to prd.json and spec files.

### Step 4: Update Progress

Append to `.ralph/tasks/progress.txt`:
- What was cleaned up, reordered, or removed
- Any gaps identified that still need planning

Update `.ralph/config/AGENT.md` with any new learnings.

### Step 5: Completion Check

After cleanup, assess vision coverage:
- If ALL areas of the vision have detailed features, well-ordered tasks, and actionable spec files: output `<promise>COMPLETE</promise>`
- If there are still gaps: output "Cleanup complete. Gaps remaining: [list areas]. Exiting for next iteration."

EXIT IMMEDIATELY after this assessment.

## CLEANUP RULES

1. **BE RUTHLESS**: Remove tasks that don't serve the vision
2. **PRESERVE INTENT**: When merging/reordering, keep the original requirements intact
3. **NO NEW FEATURES**: Only clean up existing plans — creating new features is for the plan prompt
4. **FIX ORDERING**: Features should flow naturally for sequential implementation
5. **IMPROVE SPECS**: If a spec is too vague, add details from your codebase analysis
6. **ALWAYS EXIT**: After cleanup, exit for fresh iteration
