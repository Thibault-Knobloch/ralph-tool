#!/usr/bin/env bash
set -euo pipefail

# Ralph Status - Concise status for agent consumption
# Environment: PROJECT_RALPH_DIR

PROJECT_RALPH_DIR="${PROJECT_RALPH_DIR:?PROJECT_RALPH_DIR not set}"
PRD_FILE="${PROJECT_RALPH_DIR}/tasks/prd.json"

# Color support (only if TTY)
if [[ -t 1 ]]; then
  BOLD="\033[1m"
  CYAN="\033[36m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  BLUE="\033[34m"
  DIM="\033[2m"
  RESET="\033[0m"
else
  BOLD=""
  CYAN=""
  GREEN=""
  YELLOW=""
  BLUE=""
  DIM=""
  RESET=""
fi

# Check if prd.json exists
if [[ ! -f "$PRD_FILE" ]]; then
    echo "ERROR: prd.json not found"
    exit 1
fi

# Find current feature (first incomplete feature)
CURRENT_FEATURE_ID=$(jq -r '.features[] | select(.feature_completed == false) | .id' "$PRD_FILE" 2>/dev/null | head -1)

if [[ -z "$CURRENT_FEATURE_ID" ]]; then
    echo "All features completed!"
    echo ""
    jq -r '.features[] | "  [DONE] \(.id): \(.name)"' "$PRD_FILE" 2>/dev/null
    exit 0
fi

# Get current feature details
CURRENT_FEATURE_NAME=$(jq -r --arg id "$CURRENT_FEATURE_ID" '.features[] | select(.id == $id) | .name' "$PRD_FILE" 2>/dev/null)
CURRENT_FEATURE_NUM=$(jq -r --arg id "$CURRENT_FEATURE_ID" '[.features[].id] | to_entries | .[] | select(.value == $id) | .key + 1' "$PRD_FILE" 2>/dev/null)

# Count tasks in current feature
TOTAL_TASKS=$(jq --arg id "$CURRENT_FEATURE_ID" '.features[] | select(.id == $id) | .tasks | length' "$PRD_FILE" 2>/dev/null)
COMPLETED_TASKS=$(jq --arg id "$CURRENT_FEATURE_ID" '.features[] | select(.id == $id) | [.tasks[] | select(.completed == true)] | length' "$PRD_FILE" 2>/dev/null)
PENDING_TASKS=$((TOTAL_TASKS - COMPLETED_TASKS))

# Count total features
TOTAL_FEATURES=$(jq '.features | length' "$PRD_FILE" 2>/dev/null)
COMPLETED_FEATURES=$(jq '[.features[] | select(.feature_completed == true)] | length' "$PRD_FILE" 2>/dev/null)

# Calculate border width
header="Current Feature: $CURRENT_FEATURE_NAME (Feature $CURRENT_FEATURE_NUM of $TOTAL_FEATURES)"
header_len=${#header}
border_len=$((header_len > 60 ? header_len + 4 : 64))

# Build border
border="╔"
for ((i=0; i<border_len-2; i++)); do border+="═"; done
border+="╗"

bottom_border="╚"
for ((i=0; i<border_len-2; i++)); do bottom_border+="═"; done
bottom_border+="╝"

# Human-readable output
printf "%b\n" "${BOLD}${CYAN}${border}${RESET}"
printf "%b\n" "${BOLD}${CYAN}║${RESET} ${BOLD}Current Feature:${RESET} ${YELLOW}${CURRENT_FEATURE_NAME}${RESET} ${DIM}(Feature ${CURRENT_FEATURE_NUM} of ${TOTAL_FEATURES})${RESET}"
printf "%b\n" "${BOLD}${CYAN}║${RESET} ${BOLD}Status:${RESET} ${GREEN}${COMPLETED_TASKS}${RESET}/${TOTAL_TASKS} tasks completed, ${YELLOW}${PENDING_TASKS}${RESET} pending"
printf "%b\n" "${BOLD}${CYAN}${bottom_border}${RESET}"
echo ""

# List all tasks in current feature
printf "%b\n" "${BOLD}Tasks:${RESET}"
jq -r --arg id "$CURRENT_FEATURE_ID" '.features[] | select(.id == $id) | .tasks[] | "  \(if .completed then "[DONE]" else "[TODO]" end) \(.id): \(.name)"' "$PRD_FILE" 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" =~ ^\s*\[DONE\] ]]; then
        printf "%b\n" "${DIM}${line}${RESET}"
    else
        printf "%b\n" "${BOLD}${line}${RESET}"
    fi
done

# Show next incomplete task details
echo ""
NEXT_TASK=$(jq -r --arg id "$CURRENT_FEATURE_ID" '.features[] | select(.id == $id) | .tasks[] | select(.completed == false) | .id' "$PRD_FILE" 2>/dev/null | head -1)
if [[ -n "$NEXT_TASK" ]]; then
    printf "%b\n" "${BOLD}${BLUE}Next task: ${NEXT_TASK}${RESET}"
    jq -r --arg fid "$CURRENT_FEATURE_ID" --arg tid "$NEXT_TASK" '.features[] | select(.id == $fid) | .tasks[] | select(.id == $tid) | "  Name: \(.name)\n  Spec: \(.specFile // "none")\n  Requirements: \(.requirements | join(", "))"' "$PRD_FILE" 2>/dev/null
else
    printf "%b\n" "${BOLD}${GREEN}All tasks in current feature completed - ready for feature completion!${RESET}"
fi

# Show feature overview
echo ""
printf "%b\n" "${BOLD}All Features:${RESET}"
jq -r '.features[] | "  \(if .feature_completed then "[DONE]" else "[TODO]" end) \(.id): \(.name)"' "$PRD_FILE" 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" =~ ^\s*\[DONE\] ]]; then
        printf "%b\n" "${DIM}${line}${RESET}"
    else
        printf "%b\n" "${BOLD}${line}${RESET}"
    fi
done
