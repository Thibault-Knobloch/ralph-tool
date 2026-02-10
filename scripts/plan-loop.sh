#!/usr/bin/env bash
set -euo pipefail

# Debug trap to catch where script exits early
trap 'echo "[DEBUG] Script exiting at line $LINENO with code $?" >&2' ERR

# Ralph Plan Loop - Automated feature planning from vision document
# Usage: ./plan-loop.sh [max_iterations] [model]
# Environment: RALPH_HOME, PROJECT_DIR, PROJECT_RALPH_DIR

MAX_ITERS="${1:-10}"
MODEL="${2:-}"
CLEANUP_CADENCE=5

# Use environment variables set by Node CLI
RALPH_HOME="${RALPH_HOME:?RALPH_HOME not set}"
PROJECT_RALPH_DIR="${PROJECT_RALPH_DIR:?PROJECT_RALPH_DIR not set}"

PLAN_PROMPT="${PROJECT_RALPH_DIR}/config/plan-prompt.md"
CLEANUP_PROMPT="${PROJECT_RALPH_DIR}/config/plan-cleanup-prompt.md"
VISION_FILE="${PROJECT_RALPH_DIR}/config/vision.md"

# Check required files
if [[ ! -f "$VISION_FILE" ]]; then
  echo ""
  echo "Error: Vision file not found at '$VISION_FILE'"
  echo ""
  echo "Create your vision first:"
  echo "  Use @.ralph/roles/ralph-plan-vision.md in Claude Code"
  echo ""
  exit 1
fi

if [[ ! -f "$PLAN_PROMPT" ]]; then
  echo "Error: Plan prompt not found at '$PLAN_PROMPT'"
  exit 1
fi

if [[ ! -f "$CLEANUP_PROMPT" ]]; then
  echo "Error: Plan cleanup prompt not found at '$CLEANUP_PROMPT'"
  exit 1
fi

# Platform-aware line-buffered tee
if command -v stdbuf &>/dev/null; then
  lbtee() { stdbuf -oL -eL tee "$@"; }
else
  lbtee() { tee "$@"; }
fi

# Set up paths
LOG_DIR="${PROJECT_RALPH_DIR}/logs"
HELPER_DIR="${RALPH_HOME}/helpers"
JQ_FILTER="${HELPER_DIR}/output_formatting.jq"
EXTRACT_SUBAGENT_MAP="${HELPER_DIR}/extract_subagent_map.jq"
COST_HELPERS="${HELPER_DIR}/cost_helpers.sh"
CONSTANTS="${HELPER_DIR}/constants.sh"
DISPLAY_HELPERS="${HELPER_DIR}/display_helpers.sh"
ITERATION_HELPERS="${HELPER_DIR}/iteration_helpers.sh"
mkdir -p "$LOG_DIR"

# Source helper files
if [[ ! -f "${COST_HELPERS}" ]]; then
  echo "Error: cost helpers file '${COST_HELPERS}' not found" >&2
  exit 1
fi
if [[ ! -f "${CONSTANTS}" ]]; then
  echo "Error: constants file '${CONSTANTS}' not found" >&2
  exit 1
fi
if [[ ! -f "${DISPLAY_HELPERS}" ]]; then
  echo "Error: display helpers file '${DISPLAY_HELPERS}' not found" >&2
  exit 1
fi
if [[ ! -f "${ITERATION_HELPERS}" ]]; then
  echo "Error: iteration helpers file '${ITERATION_HELPERS}' not found" >&2
  exit 1
fi

source "${COST_HELPERS}"
source "${CONSTANTS}"
source "${DISPLAY_HELPERS}"
source "${ITERATION_HELPERS}"

# Verify jq filter files exist
if [[ ! -f "${JQ_FILTER}" ]]; then
  echo "Error: jq filter file '${JQ_FILTER}' not found"
  exit 1
fi
if [[ ! -f "${EXTRACT_SUBAGENT_MAP}" ]]; then
  echo "Error: subagent map extractor '${EXTRACT_SUBAGENT_MAP}' not found"
  exit 1
fi

# Status tracking
ITERATIONS_RUN=0
AREAS_PLANNED=0
TOTAL_SUBAGENTS=0

# Cost tracking
TOTAL_COST="0.0"
TOTAL_INPUT_TOKENS=0
TOTAL_OUTPUT_TOKENS=0
TOTAL_CACHE_READ_TOKENS=0
TOTAL_CACHE_WRITE_TOKENS=0

# Time tracking
START_TIME=$(date +%s)

# Get fun name for this run and show startup banner
RALPH_NAME=$(get_ralph_name)
show_startup_banner "$RALPH_NAME" "$MAX_ITERS" "$MODEL"

echo "  Mode: PLANNING (from vision.md)"
echo "  Cleanup every ${CLEANUP_CADENCE} iterations"
echo ""

# Main iteration loop
for ((ITER=1; ITER<=MAX_ITERS; ITER++)); do
  # Create timestamped log files
  TS="$(date +%Y%m%d_%H%M%S)"
  RAW_LOG="${LOG_DIR}/plan_iter_${ITER}_${TS}.raw.jsonl"
  PRETTY_LOG="${LOG_DIR}/plan_iter_${ITER}_${TS}.pretty.log"
  SUBAGENT_MAP_FILE="${LOG_DIR}/plan_iter_${ITER}_${TS}.subagent_map.json"

  # Select prompt: cleanup every Nth iteration
  if (( ITER > 1 && ITER % CLEANUP_CADENCE == 0 )); then
    CURRENT_PROMPT="$CLEANUP_PROMPT"
    ITER_TYPE="CLEANUP"
  else
    CURRENT_PROMPT="$PLAN_PROMPT"
    ITER_TYPE="PLAN"
  fi

  # Get fun name for this iteration and show header
  ITER_NAME=$(get_ralph_name)
  show_iteration_header "$ITER_NAME" "$ITER" "$MAX_ITERS" "$AREAS_PLANNED"

  if [[ "$ITER_TYPE" == "CLEANUP" ]]; then
    echo "  ⟳ CLEANUP ITERATION — reviewing and consolidating plans"
    echo ""
  fi

  show_thinking 1

  # Build claude command with optional model parameter
  CLAUDE_CMD="claude"
  [[ -n "$MODEL" ]] && CLAUDE_CMD="$CLAUDE_CMD --model $MODEL"

  # Run Claude with selected prompt
  set +e
  OUTPUT="$(
    cat "$CURRENT_PROMPT" | $CLAUDE_CMD \
      --dangerously-skip-permissions \
      --print \
      --verbose \
      --output-format=stream-json \
      --include-partial-messages \
      --tools default \
      --disallowedTools "mcp__brave-search__brave_web_search,mcp__brave-search__brave_local_search,WebSearch,web_search" \
      --debug \
      2>&1 \
      | lbtee "$RAW_LOG" \
      | jq --unbuffered -rj -f "$JQ_FILTER" \
          --argjson MAX "$MAX_CHARS" \
          --argjson COLOR "$USE_COLOR" \
          --argjson MAX_LINES "$MAX_LINES_FOR_TOOL_RESULT" \
          --argjson SUBAGENT_MAP "{}" \
          2>/dev/null \
      | tee >(cat >&2) \
      | lbtee "$PRETTY_LOG"
  )"
  CLAUDE_EXIT_CODE=$?
  set -e

  # Process subagent mapping and cost data
  if [[ -f "$RAW_LOG" ]] && [[ -s "$RAW_LOG" ]]; then
    # Process subagent mapping
    SUBAGENT_COUNT=$(process_subagent_mapping "$RAW_LOG" "$SUBAGENT_MAP_FILE" "$EXTRACT_SUBAGENT_MAP")
    if [[ "$SUBAGENT_COUNT" -gt 0 ]]; then
      TOTAL_SUBAGENTS=$((TOTAL_SUBAGENTS + SUBAGENT_COUNT))
      reformat_pretty_log "$RAW_LOG" "$PRETTY_LOG" "$SUBAGENT_MAP_FILE" "$JQ_FILTER" "$MAX_CHARS" "$USE_COLOR" "$MAX_LINES_FOR_TOOL_RESULT"
    fi

    # Process iteration cost
    COST_DATA=$(process_iteration_cost "$RAW_LOG" "$DEFAULT_MODEL")
    if [[ -n "$COST_DATA" ]]; then
      read -r ITER_MODEL ITER_COST ITER_ACTUAL_INPUT ITER_OUTPUT_TOKENS ITER_CACHE_READ ITER_CACHE_WRITE <<< "$COST_DATA"

      # Update totals
      TOTAL_COST=$(echo "scale=6; $TOTAL_COST + $ITER_COST" | bc -l)
      TOTAL_INPUT_TOKENS=$((TOTAL_INPUT_TOKENS + ITER_ACTUAL_INPUT))
      TOTAL_OUTPUT_TOKENS=$((TOTAL_OUTPUT_TOKENS + ITER_OUTPUT_TOKENS))
      TOTAL_CACHE_READ_TOKENS=$((TOTAL_CACHE_READ_TOKENS + ITER_CACHE_READ))
      TOTAL_CACHE_WRITE_TOKENS=$((TOTAL_CACHE_WRITE_TOKENS + ITER_CACHE_WRITE))

      # Display iteration cost summary
      show_iteration_cost_summary "$ITER_MODEL" "$ITER_COST" "$ITER_ACTUAL_INPUT" "$ITER_OUTPUT_TOKENS" "$ITER_CACHE_READ" "$ITER_CACHE_WRITE"
    fi
  fi

  ITERATIONS_RUN=$((ITERATIONS_RUN + 1))

  # Check for completion signals
  if grep -q "<promise>COMPLETE</promise>" <<<"$OUTPUT"; then
    ELAPSED_SECONDS=$(($(date +%s) - START_TIME))
    show_completion_message "$ITERATIONS_RUN" "$TOTAL_SUBAGENTS" "$TOTAL_COST" "$TOTAL_INPUT_TOKENS" "$TOTAL_OUTPUT_TOKENS" "$TOTAL_CACHE_READ_TOKENS" "$TOTAL_CACHE_WRITE_TOKENS" "$ELAPSED_SECONDS"
    exit 0
  fi

  if grep -q "<promise>STUCK</promise>" <<<"$OUTPUT"; then
    ELAPSED_SECONDS=$(($(date +%s) - START_TIME))
    show_stuck_message "$ITERATIONS_RUN" "$TOTAL_COST" "$TOTAL_INPUT_TOKENS" "$TOTAL_OUTPUT_TOKENS" "$TOTAL_CACHE_READ_TOKENS" "$TOTAL_CACHE_WRITE_TOKENS" "$ELAPSED_SECONDS"
    exit 1
  fi

  # Track planning progress
  if grep -q "Planned .*\. Exiting for next iteration" <<<"$OUTPUT"; then
    AREAS_PLANNED=$((AREAS_PLANNED + 1))
  fi

  # No check_feature_completion — planning doesn't trigger git/PRs

  # Brief pause between iterations
  if [[ $ITER -lt $MAX_ITERS ]]; then
    show_thinking 2
  fi
done

# Max iterations reached
ELAPSED_SECONDS=$(($(date +%s) - START_TIME))
show_max_iterations_message "$ITERATIONS_RUN" "$AREAS_PLANNED" "$TOTAL_SUBAGENTS" "$TOTAL_COST" "$TOTAL_INPUT_TOKENS" "$TOTAL_OUTPUT_TOKENS" "$TOTAL_CACHE_READ_TOKENS" "$TOTAL_CACHE_WRITE_TOKENS" "$ELAPSED_SECONDS"
exit 2
