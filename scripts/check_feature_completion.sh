#!/usr/bin/env bash
set -euo pipefail

# Ralph Auto Feature Completion Check
# Called automatically after each loop iteration
# Environment: RALPH_HOME, PROJECT_RALPH_DIR

RALPH_NAME="${1:-RALPH}"

RALPH_HOME="${RALPH_HOME:?RALPH_HOME not set}"
PROJECT_RALPH_DIR="${PROJECT_RALPH_DIR:?PROJECT_RALPH_DIR not set}"

PRD_FILE="${PROJECT_RALPH_DIR}/tasks/prd.json"
PROGRESS_FILE="${PROJECT_RALPH_DIR}/tasks/progress.txt"
PROGRESS_ARCHIVE_DIR="${PROJECT_RALPH_DIR}/logs/progress"

# Verify PRD file exists
if [[ ! -f "$PRD_FILE" ]]; then
    exit 0
fi

# Check if multi-feature format
IS_MULTI_FEATURE=$(jq 'has("features")' "$PRD_FILE" 2>/dev/null)
if [[ "$IS_MULTI_FEATURE" != "true" ]]; then
    exit 0
fi

# Find current feature (first incomplete one)
CURRENT_FEATURE=$(jq -r '.features[] | select(.feature_completed == false) | .id' "$PRD_FILE" 2>/dev/null | head -1)

if [[ -z "$CURRENT_FEATURE" ]]; then
    exit 0
fi

# Check if all tasks in current feature are completed
ALL_TASKS_DONE=$(jq --arg id "$CURRENT_FEATURE" '
    .features[] | select(.id == $id) |
    (.tasks | length > 0) and (.tasks | all(.completed == true))
' "$PRD_FILE" 2>/dev/null)

if [[ "$ALL_TASKS_DONE" != "true" ]]; then
    exit 0
fi

# Check if feature is already marked complete
FEATURE_ALREADY_COMPLETE=$(jq --arg id "$CURRENT_FEATURE" '
    .features[] | select(.id == $id) | .feature_completed
' "$PRD_FILE" 2>/dev/null)

if [[ "$FEATURE_ALREADY_COMPLETE" == "true" ]]; then
    exit 0
fi

# === All tasks done, feature not yet marked complete - proceed ===

# Get feature name for archive filename
FEATURE_NAME=$(jq -r --arg id "$CURRENT_FEATURE" '.features[] | select(.id == $id) | .name' "$PRD_FILE" 2>/dev/null)
FEATURE_NAME_KEBAB=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  AUTO-COMPLETING FEATURE: $FEATURE_NAME"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Step 1: Update prd.json - set feature_completed: true
echo "[1/4] Marking feature as completed in prd.json..."
jq --arg id "$CURRENT_FEATURE" '(.features[] | select(.id == $id) | .feature_completed) = true' "$PRD_FILE" > "${PRD_FILE}.tmp"
mv "${PRD_FILE}.tmp" "$PRD_FILE"
echo "  ✓ Feature $CURRENT_FEATURE marked as completed"

# Step 2: Git operations
if [[ "${RALPH_LOCAL:-}" == "1" ]]; then
    echo "[2/4] Committing changes locally (--local mode, skipping branch/push/PR)..."
    git add -A -- ':!.ralph'
    git commit -m "RALPH: ${FEATURE_NAME}" || echo "  ⓘ Nothing to commit"
    echo "  ✓ Changes committed on current branch"
else
    echo "[2/4] Creating git branch and PR for feature..."
    "${RALPH_HOME}/scripts/git_feature_complete.sh" "$FEATURE_NAME" "$FEATURE_NAME_KEBAB" "$RALPH_NAME" "$PROGRESS_FILE"
fi

# Step 3: Archive progress.txt
echo "[3/4] Archiving progress.txt..."
mkdir -p "$PROGRESS_ARCHIVE_DIR"

if [[ -f "$PROGRESS_FILE" && -s "$PROGRESS_FILE" ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ARCHIVE_FILE="${PROGRESS_ARCHIVE_DIR}/${FEATURE_NAME_KEBAB}-progress-${TIMESTAMP}.txt"
    cp "$PROGRESS_FILE" "$ARCHIVE_FILE"
    echo "  ✓ Archived to: $ARCHIVE_FILE"
else
    echo "  ⓘ No progress.txt to archive (empty or missing)"
fi

# Step 4: Clear progress.txt for next feature
echo "[4/4] Clearing progress.txt for next feature..."
: > "$PROGRESS_FILE"
echo "  ✓ progress.txt cleared"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  FEATURE '$FEATURE_NAME' AUTO-COMPLETED"
echo "═══════════════════════════════════════════════════════════════"

# Check if there's a next feature
NEXT_FEATURE=$(jq -r '.features[] | select(.feature_completed == false) | .name' "$PRD_FILE" 2>/dev/null | head -1)
if [[ -n "$NEXT_FEATURE" ]]; then
    echo "  Next feature: $NEXT_FEATURE"
    echo ""
    exit 0
else
    echo "  🎉 ALL FEATURES COMPLETED!"
    echo ""
    exit 99
fi
