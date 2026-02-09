#!/usr/bin/env bash
set -euo pipefail

# Ralph Review - PR Summary & Merge Automation
# Environment: PROJECT_RALPH_DIR

PROJECT_RALPH_DIR="${PROJECT_RALPH_DIR:?PROJECT_RALPH_DIR not set}"
PROMPT_FILE="${PROJECT_RALPH_DIR}/config/pr-review-prompt.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[1;36m'
NC='\033[0m'

echo ""
echo -e "${LIGHT_BLUE}Ralph Review - PR Summary & Merge${NC}"
echo ""

# Verify prompt file exists
if [[ ! -f "$PROMPT_FILE" ]]; then
    echo -e "${RED}Error: Prompt file not found at ${PROMPT_FILE}${NC}"
    exit 1
fi

# 1. Get latest open PR
echo "[1/5] Checking for open PRs..."
PR_JSON=$(gh pr list --state open --limit 1 --json number,title,body)
PR_NUMBER=$(echo "$PR_JSON" | jq -r '.[0].number // empty')

if [[ -z "$PR_NUMBER" ]]; then
    echo -e "${RED}No open PRs found${NC}"
    exit 1
fi

PR_TITLE=$(echo "$PR_JSON" | jq -r '.[0].title')
PR_BODY=$(echo "$PR_JSON" | jq -r '.[0].body')
echo -e "  ${GREEN}✓${NC} Found PR #${PR_NUMBER}: ${PR_TITLE}"

# 2. Get PR diff
echo "[2/5] Fetching PR diff..."
PR_DIFF=$(gh pr diff "$PR_NUMBER")
echo -e "  ${GREEN}✓${NC} Diff fetched"

# 3. Generate summary via Claude
echo "[3/5] Generating PR summary via Claude..."
PR_CONTEXT="PR #${PR_NUMBER}: ${PR_TITLE}

## PR Description
${PR_BODY}

## Diff
${PR_DIFF}"

PROMPT=$(cat "$PROMPT_FILE")

# Call Claude and capture output
SUMMARY=$(echo "$PR_CONTEXT" | claude --dangerously-skip-permissions --print -p "$PROMPT" 2>&1) || {
    echo -e "${RED}Claude failed to generate summary${NC}"
    exit 1
}

echo ""
echo "==============================================================================="
echo -e "${LIGHT_BLUE}PR #${PR_NUMBER} Summary${NC}"
echo "==============================================================================="
echo ""
echo "$SUMMARY"
echo ""
echo "==============================================================================="
echo ""

# 4. Merge PR
echo "[4/5] Merging PR #${PR_NUMBER}..."
if ! gh pr merge "$PR_NUMBER" --squash --delete-branch; then
    echo -e "${RED}Merge failed - check for conflicts${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} PR merged and branch deleted"

# 5. Update local
echo "[5/5] Updating local main branch..."
git checkout main
git pull
echo -e "  ${GREEN}✓${NC} Local main updated"

echo ""
echo -e "${GREEN}Review complete!${NC}"
echo ""
