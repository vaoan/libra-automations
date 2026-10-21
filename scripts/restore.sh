#!/usr/bin/env bash
# Restore a backup made by backup.sh. Overwrites the current n8n database and data.
# Works on macOS and on Windows 11 via Git Bash. Requires the same .env as the source.
# Usage: scripts/restore.sh backups/libra-automations-YYYYmmdd-HHMMSS.tar.gz
set -euo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

archive=${1:?usage: scripts/restore.sh <backup.tar.gz>}
work="backups/restore-tmp"
rm -rf "$work"; mkdir -p "$work"
tar xzf "$archive" -C "$work"

docker compose stop n8n 2>/dev/null || true
docker compose up -d postgres
until docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do sleep 2; done
docker compose exec -T postgres psql -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$work/db.sql"

docker volume create libra-automations_n8n_data >/dev/null
docker run --rm -v libra-automations_n8n_data:/data -v "$PWD/$work:/backup" alpine \
  sh -c 'rm -rf /data/* /data/.[!.]* 2>/dev/null; tar xzf /backup/n8n_data.tar.gz -C /data && chown -R 1000:1000 /data'

docker compose up -d
rm -rf "$work"
echo "Restored from $archive."
