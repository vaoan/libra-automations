#!/usr/bin/env bash
# Full backup (n8n Postgres dump + n8n data volume) into backups/<timestamp>.tar.gz.
# Works on macOS and on Windows 11 via Git Bash.
# Usage: scripts/backup.sh [--stop]   (--stop leaves the stack down, for migration)
set -euo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

stamp=$(date +%Y%m%d-%H%M%S)
work="backups/tmp-$stamp"
mkdir -p "$work"

docker compose up -d postgres
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists > "$work/db.sql"

docker compose stop n8n
docker run --rm -v libra-automations_n8n_data:/data -v "$PWD/$work:/backup" alpine \
  tar czf /backup/n8n_data.tar.gz -C /data .

if [ "${1:-}" = "--stop" ]; then
  docker compose down
else
  docker compose up -d
fi

tar czf "backups/libra-automations-$stamp.tar.gz" -C "$work" .
rm -rf "$work"
echo "Backup: backups/libra-automations-$stamp.tar.gz"
