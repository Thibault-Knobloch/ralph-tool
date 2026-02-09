#!/usr/bin/env bash
# Open interactive Docker sandbox environment
# Environment: RALPH_HOME, PROJECT_DIR

set -euo pipefail

RALPH_HOME="${RALPH_HOME:?RALPH_HOME not set}"
PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR not set}"

# Run interactive bash in Docker container
docker compose -f "${RALPH_HOME}/docker-compose.yaml" run --rm \
    -v "${PROJECT_DIR}:/workspace:rw" \
    -e PROJECT_DIR=/workspace \
    -e PROJECT_RALPH_DIR=/workspace/.ralph \
    ai bash
