#!/usr/bin/env bash
set -euo pipefail

# Git Feature Complete - Creates branch, commits, pushes, and opens PR
# Usage: ./git_feature_complete.sh <feature_name> <feature_name_slug> <ralph_name> <progress_file> [--dry-run]

# Check for --dry-run flag
DRY_RUN=false
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    fi
done

FEATURE_NAME="${1:-}"
FEATURE_NAME_SLUG="${2:-}"
RALPH_NAME="${3:-RALPH}"
PROGRESS_FILE="${4:-}"

if [[ -z "$FEATURE_NAME" || -z "$FEATURE_NAME_SLUG" ]]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <feature_name> <feature_name_slug> <ralph_name> <progress_file> [--dry-run]"
    exit 1
fi

BRANCH_NAME="RALPH-DID-${FEATURE_NAME_SLUG}"

# Check if branch exists and find unique name
BASE_BRANCH_NAME="$BRANCH_NAME"
COUNTER=2
while git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; do
    BRANCH_NAME="${BASE_BRANCH_NAME}-${COUNTER}"
    COUNTER=$((COUNTER + 1))
done

if [[ "$BRANCH_NAME" != "$BASE_BRANCH_NAME" ]]; then
    echo "  ⓘ Branch '$BASE_BRANCH_NAME' already exists, using '$BRANCH_NAME' instead"
fi

# Helper function to run or print commands
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY-RUN] Would execute: $*"
    else
        "$@"
    fi
}

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  GIT: DRY RUN - Creating PR for completed feature           │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
else
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  GIT: Creating PR for completed feature                     │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
fi

# Step 1: Stage all changes (excluding .ralph folder)
echo "[git 1/6] Staging all changes (excluding .ralph)..."
run_cmd git add -A -- ':!.ralph'
echo "  ✓ All changes staged"

# Step 2: Create feature branch
echo "[git 2/6] Creating branch: ${BRANCH_NAME}..."
run_cmd git checkout -b "$BRANCH_NAME"
echo "  ✓ Branch created"

# Step 3: Commit changes
echo "[git 3/6] Committing changes..."
run_cmd git commit -m "RALPH: ${FEATURE_NAME}"
echo "  ✓ Changes committed"

# Step 4: Push to origin
echo "[git 4/6] Pushing to origin..."
run_cmd git push -u origin "$BRANCH_NAME"
echo "  ✓ Pushed to origin/${BRANCH_NAME}"

# Step 5: Create PR
echo "[git 5/6] Creating Pull Request..."

# Build PR body
PR_BODY="## ${RALPH_NAME} completed this feature

"

# Add progress content if file exists and has content
if [[ -n "$PROGRESS_FILE" && -f "$PROGRESS_FILE" && -s "$PROGRESS_FILE" ]]; then
    PR_BODY+="$(cat "$PROGRESS_FILE")"
else
    PR_BODY+="_No progress notes available._"
fi

PR_BODY+="

---
_Automated PR by Ralph_"

PR_TITLE="Ralph needs review on ${FEATURE_NAME}"

if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY-RUN] Would execute: gh pr create --base main --head $BRANCH_NAME --title \"$PR_TITLE\""
    echo "  [DRY-RUN] PR Body would be:"
    echo "  ────────────────────────────────────────"
    echo "$PR_BODY" | sed 's/^/  │ /'
    echo "  ────────────────────────────────────────"
    PR_URL="https://github.com/REPO/pull/XXX (dry-run)"
else
    PR_URL=$(gh pr create \
        --base main \
        --head "$BRANCH_NAME" \
        --title "$PR_TITLE" \
        --body "$PR_BODY")
fi

echo "  ✓ PR created: $PR_URL"

# Step 6: Switch back to main
echo "[git 6/6] Switching back to main..."
run_cmd git checkout main
echo "  ✓ Back on main branch (clean state)"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  ✓ Feature branch ready for review!                         │"
echo "│  Branch: ${BRANCH_NAME}"
echo "│  PR: ${PR_URL}"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
