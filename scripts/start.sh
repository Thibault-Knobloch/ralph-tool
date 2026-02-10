#!/usr/bin/env bash
# Combined script to start sandbox and run Ralph loop inside container
# Environment: RALPH_HOME, PROJECT_DIR, PROJECT_RALPH_DIR

set -euo pipefail

MAX_ITERS="${1:-6}"
MODEL="${2:-}"

RALPH_HOME="${RALPH_HOME:?RALPH_HOME not set}"
PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR not set}"

# Build ralph command with optional model parameter
RALPH_CMD="ralph loop"
[[ -n "$MODEL" ]] && RALPH_CMD="$RALPH_CMD --model $MODEL"
RALPH_CMD="$RALPH_CMD --max ${MAX_ITERS}"
[[ "${RALPH_LOCAL:-}" == "1" ]] && RALPH_CMD="$RALPH_CMD --local"

# Run the ralph loop command inside the Docker container
# Mount the project directory to /workspace
docker compose -f "${RALPH_HOME}/docker-compose.yaml" run --rm \
    -v "${PROJECT_DIR}:/workspace:rw" \
    -e PROJECT_DIR=/workspace \
    -e PROJECT_RALPH_DIR=/workspace/.ralph \
    ai bash -c "${RALPH_CMD}"
