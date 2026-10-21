#!/usr/bin/env bash
# Create .env from .env.example with freshly generated secrets.
# Run ONCE on the first machine; copy the resulting .env to any other machine.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo ".env already exists — not overwriting (it holds the encryption key)." >&2
  exit 1
fi

rand() { openssl rand -hex "$1"; }

sed -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(rand 16)|" \
    -e "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$(rand 32)|" \
    -e "s|^LIBRA_WEBHOOK_SECRET=.*|LIBRA_WEBHOOK_SECRET=$(rand 24)|" \
    .env.example > .env
chmod 600 .env
echo "Created .env. Back it up in a password manager — it is NOT in git."
