#!/usr/bin/env bash
# Auto mode: run plan-loop first, then start execution loop
# Usage: ./auto.sh [plan_max] [start_max] [model] [local] [sandbox]
# Environment: RALPH_HOME, PROJECT_DIR, PROJECT_RALPH_DIR

set -euo pipefail

PLAN_MAX="${1:-10}"
START_MAX="${2:-6}"
MODEL="${3:-}"
IS_LOCAL="${4:-}"
USE_SANDBOX="${5:-}"

RALPH_HOME="${RALPH_HOME:?RALPH_HOME not set}"
PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR not set}"
PROJECT_RALPH_DIR="${PROJECT_RALPH_DIR:?PROJECT_RALPH_DIR not set}"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  RALPH AUTO MODE"
echo "  Phase 1: Plan (up to ${PLAN_MAX} iterations)"
echo "  Phase 2: Execute (up to ${START_MAX} iterations)"
echo "══════════════════════════════════════════════════════════"
echo ""

# ── Phase 1: Planning ──────────────────────────────────────
echo ">>> Starting Phase 1: PLANNING"
echo ""

set +e
if [[ "$USE_SANDBOX" == "1" ]]; then
  echo "  Running plan in Docker sandbox..."
  echo ""
  RALPH_PLAN_CMD="ralph plan --max ${PLAN_MAX}"
  [[ -n "$MODEL" ]] && RALPH_PLAN_CMD="$RALPH_PLAN_CMD --model $MODEL"
  docker compose -f "${RALPH_HOME}/docker-compose.yaml" run --rm \
      -v "${PROJECT_DIR}:/workspace:rw" \
      -e PROJECT_DIR=/workspace \
      -e PROJECT_RALPH_DIR=/workspace/.ralph \
      ai bash -c "${RALPH_PLAN_CMD}"
  PLAN_EXIT=$?
else
  PLAN_SCRIPT="${RALPH_HOME}/scripts/plan-loop.sh"
  bash "$PLAN_SCRIPT" "$PLAN_MAX" "$MODEL"
  PLAN_EXIT=$?
fi
set -e

if [[ $PLAN_EXIT -eq 1 ]]; then
  echo ""
  echo "Planning got STUCK (exit code 1). Aborting auto mode."
  exit 1
fi

# Exit codes 0 (COMPLETE) and 2 (max iterations) both mean we have tasks to work on
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Planning phase finished (exit code: ${PLAN_EXIT})"
echo "  Moving to execution phase..."
echo "══════════════════════════════════════════════════════════"
echo ""

# ── Phase 2: Execution ─────────────────────────────────────
echo ">>> Starting Phase 2: EXECUTION"
echo ""

set +e
if [[ "$USE_SANDBOX" == "1" ]]; then
  echo "  Running in Docker sandbox..."
  echo ""
  START_SCRIPT="${RALPH_HOME}/scripts/start.sh"
  bash "$START_SCRIPT" "$START_MAX" "$MODEL"
  LOOP_EXIT=$?
else
  PROMPT_FILE="${PROJECT_RALPH_DIR}/config/prompt.md"
  LOOP_SCRIPT="${RALPH_HOME}/scripts/loop.sh"
  bash "$LOOP_SCRIPT" "$PROMPT_FILE" "$START_MAX" "$MODEL"
  LOOP_EXIT=$?
fi
set -e

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Auto mode complete"
echo "  Plan exit: ${PLAN_EXIT} | Execute exit: ${LOOP_EXIT}"
echo "══════════════════════════════════════════════════════════"
echo ""

exit $LOOP_EXIT
