#!/usr/bin/env bash
set -euo pipefail

# Ralph Clear - Delete all log files (keeps progress folder)
# Environment: PROJECT_RALPH_DIR

PROJECT_RALPH_DIR="${PROJECT_RALPH_DIR:?PROJECT_RALPH_DIR not set}"
LOG_DIR="${PROJECT_RALPH_DIR}/logs"

# Color support (only if TTY)
if [[ -t 1 ]]; then
  GREEN="\033[32m"
  YELLOW="\033[33m"
  RESET="\033[0m"
else
  GREEN=""
  YELLOW=""
  RESET=""
fi

# Check if logs directory exists
if [[ ! -d "$LOG_DIR" ]]; then
    echo "Logs directory not found: $LOG_DIR"
    exit 0
fi

# Count files to be deleted (excluding progress directory)
FILE_COUNT=$(find "$LOG_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')

if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}No log files to clear.${RESET}"
    exit 0
fi

# Delete all files in logs directory (but not subdirectories like progress)
find "$LOG_DIR" -maxdepth 1 -type f -delete

echo -e "${GREEN}Cleared ${FILE_COUNT} log files.${RESET}"
