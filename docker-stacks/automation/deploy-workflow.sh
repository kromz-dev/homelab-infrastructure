#!/usr/bin/env bash
# Usage: ./deploy-workflow.sh <workflow-dir-name>
# Fills credentials.tpl.json and workflow.json from workflows/<name>/.env
# and imports both into the running n8n container. Does NOT activate the workflow.
set -euo pipefail
cd "$(dirname "$0")/workflows/${1:?workflow name}"
[ -f .env ] || { echo "missing .env (copy .env.example)"; exit 1; }
set -a; . ./.env; set +a
empty=$(grep -E '^[A-Z_]+=$' .env | cut -d= -f1 || true)
[ -z "$empty" ] || { echo "empty values in .env: $empty"; exit 1; }
vars=$(sed -n 's/^\([A-Z_][A-Z_0-9]*\)=.*/$\1/p' .env | tr '\n' ' ')
for f in credentials workflow; do
  src=$f.tpl.json; [ -f "$src" ] || src=$f.json
  envsubst "$vars" < "$src" | docker exec -i n8n sh -c "cat > /tmp/$f.json"
  docker exec n8n n8n import:$f --input=/tmp/$f.json
  docker exec n8n rm -f /tmp/$f.json
done
