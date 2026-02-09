#!/usr/bin/env bash
set -euo pipefail

# Ralph Cleanup - Archive Completed Features
# Environment: RALPH_HOME, PROJECT_RALPH_DIR

RALPH_HOME="${RALPH_HOME:?RALPH_HOME not set}"
PROJECT_RALPH_DIR="${PROJECT_RALPH_DIR:?PROJECT_RALPH_DIR not set}"

TASKS_DIR="${PROJECT_RALPH_DIR}/tasks"
NEW_TASKS_DIR="${TASKS_DIR}/1_new_tasks"
DONE_TASKS_DIR="${TASKS_DIR}/2_done_tasks"
PROGRESS_DIR="${PROJECT_RALPH_DIR}/logs/progress"
PRD_FILE="${TASKS_DIR}/prd.json"

FEATURE_ARG="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[1;36m'
NC='\033[0m'

echo ""
echo -e "${LIGHT_BLUE}Ralph Cleanup - Archive Completed Features${NC}"
echo ""

# 1. Clear iteration logs
echo "[1/4] Clearing iteration logs..."
"${RALPH_HOME}/scripts/clear.sh" > /dev/null 2>&1 || true
echo -e "  ${GREEN}✓${NC} Logs cleared"

# 2. Parse prd.json and find completed features
echo "[2/4] Finding completed features..."

if [[ ! -f "$PRD_FILE" ]]; then
    echo -e "${RED}Error: prd.json not found${NC}"
    exit 1
fi

# Get completed features as JSON array
COMPLETED_FEATURES=$(jq '[.features[] | select(.feature_completed == true)]' "$PRD_FILE")
COMPLETED_COUNT=$(echo "$COMPLETED_FEATURES" | jq 'length')

if [[ "$COMPLETED_COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}No completed features to cleanup${NC}"
    exit 0
fi

# If feature arg provided, filter to just that feature
if [[ -n "$FEATURE_ARG" ]]; then
    ARG_LOWER=$(echo "$FEATURE_ARG" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    MATCHED_FEATURE=$(echo "$COMPLETED_FEATURES" | jq --arg arg "$ARG_LOWER" '
        [.[] | select(
            (.name | ascii_downcase | gsub(" "; "-")) == $arg or
            (.name | ascii_downcase | gsub(" "; "-") | contains($arg)) or
            (.id | ascii_downcase) == $arg
        )] | .[0] // empty
    ')

    if [[ -z "$MATCHED_FEATURE" || "$MATCHED_FEATURE" == "null" ]]; then
        echo -e "${RED}Feature '${FEATURE_ARG}' not found in completed features${NC}"
        echo "Completed features:"
        echo "$COMPLETED_FEATURES" | jq -r '.[].name' | sed 's/^/  - /'
        exit 1
    fi

    COMPLETED_FEATURES="[$MATCHED_FEATURE]"
    COMPLETED_COUNT=1
fi

echo -e "  ${GREEN}✓${NC} Found ${COMPLETED_COUNT} completed feature(s)"

# Helper: Convert feature name to slug
to_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g'
}

# Helper: Convert slug to camelCase
to_camel_case() {
    echo "$1" | awk -F'-' '{
        for(i=1; i<=NF; i++) {
            if(i==1) printf "%s", $i
            else printf "%s", toupper(substr($i,1,1)) substr($i,2)
        }
    }'
}

# 3. Process each feature
echo "[3/4] Archiving features..."
CLEANED_FEATURES=()
CLEANED_IDS=()

for i in $(seq 0 $((COMPLETED_COUNT - 1))); do
    FEATURE=$(echo "$COMPLETED_FEATURES" | jq ".[$i]")
    FEATURE_NAME=$(echo "$FEATURE" | jq -r '.name')
    FEATURE_ID=$(echo "$FEATURE" | jq -r '.id')
    SPEC_FILE=$(echo "$FEATURE" | jq -r '.tasks[0].specFile // empty')

    SLUG=$(to_slug "$FEATURE_NAME")
    CAMEL_CASE=$(to_camel_case "$SLUG")

    echo "  Processing: ${FEATURE_NAME}"

    # Create done folder
    DONE_FOLDER="${DONE_TASKS_DIR}/${CAMEL_CASE}"
    mkdir -p "$DONE_FOLDER"

    # Move spec file
    SPEC_MOVED=false

    if [[ -n "$SPEC_FILE" ]]; then
        SPEC_PATH="${PROJECT_RALPH_DIR}/../${SPEC_FILE}"
        if [[ -f "$SPEC_PATH" ]]; then
            mv "$SPEC_PATH" "$DONE_FOLDER/"
            SPEC_MOVED=true
        fi
    fi

    if [[ "$SPEC_MOVED" == false ]]; then
        FOUND_SPEC=$(find "$NEW_TASKS_DIR" -maxdepth 1 -name "*${SLUG}*" -type f 2>/dev/null | head -1)
        if [[ -n "$FOUND_SPEC" && -f "$FOUND_SPEC" ]]; then
            mv "$FOUND_SPEC" "$DONE_FOLDER/"
            SPEC_MOVED=true
        fi
    fi

    if [[ "$SPEC_MOVED" == true ]]; then
        echo -e "    ${GREEN}✓${NC} Moved spec file"
    else
        echo -e "    ${YELLOW}⚠${NC} Spec file not found"
    fi

    # Move progress file(s)
    if [[ -d "$PROGRESS_DIR" ]]; then
        PROGRESS_MOVED=false
        while IFS= read -r -d '' pfile; do
            if [[ -f "$pfile" ]]; then
                mv "$pfile" "$DONE_FOLDER/"
                PROGRESS_MOVED=true
            fi
        done < <(find "$PROGRESS_DIR" -maxdepth 1 -name "*${SLUG}*" -type f -print0 2>/dev/null)

        if [[ "$PROGRESS_MOVED" == true ]]; then
            echo -e "    ${GREEN}✓${NC} Moved progress file(s)"
        else
            echo -e "    ${YELLOW}⚠${NC} No progress files found"
        fi
    else
        echo -e "    ${YELLOW}⚠${NC} Progress directory not found"
    fi

    CLEANED_FEATURES+=("$CAMEL_CASE")
    CLEANED_IDS+=("$FEATURE_ID")
done

# 4. Update prd.json - remove cleaned features
echo "[4/4] Updating prd.json..."

if [[ -n "$FEATURE_ARG" ]]; then
    FEATURE_ID=$(echo "$COMPLETED_FEATURES" | jq -r '.[0].id')
    jq --arg id "$FEATURE_ID" '.features = [.features[] | select(.id != $id)]' "$PRD_FILE" > "${PRD_FILE}.tmp"
else
    jq '.features = [.features[] | select(.feature_completed != true)]' "$PRD_FILE" > "${PRD_FILE}.tmp"
fi

mv "${PRD_FILE}.tmp" "$PRD_FILE"
echo -e "  ${GREEN}✓${NC} prd.json updated"

# Summary
echo ""
echo -e "${GREEN}Cleanup complete!${NC}"
echo "Archived ${#CLEANED_FEATURES[@]} feature(s):"
for f in "${CLEANED_FEATURES[@]}"; do
    echo "  - 2_done_tasks/${f}/"
done
echo ""
