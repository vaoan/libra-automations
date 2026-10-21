#!/usr/bin/env bash
# Run a workflow once from the CLI (e.g. a scheduled one, without waiting for its cron).
# Usage: scripts/run-workflow.sh LibraStaleRemind1 | LibraWeeklyRpt01
set -euo pipefail
cd "$(dirname "$0")/.."

id=${1:?usage: scripts/run-workflow.sh <workflow-id>}
# The running n8n already holds the task broker port (5679); the CLI needs its own.
docker compose exec -T -e N8N_RUNNERS_BROKER_PORT=5690 n8n n8n execute --id="$id" 2>&1 \
  | grep -E '^Execution was|"executionStatus"|Error' || true
