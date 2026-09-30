#!/usr/bin/env bash
# Usage: ./deploy-workflow.sh <workflow-dir-name>
# Fills credentials.tpl.json and workflow.json from workflows/<name>/.env and imports both
# into the running n8n container. An optional executable pre-deploy.sh in the workflow
# directory runs first (it may edit .env). A workflow that was active stays active (the import
# deactivates it, so it is published again); a new one is left inactive.
set -euo pipefail
cd "$(dirname "$0")/workflows/${1:?workflow name}"
[ -f .env ] || { echo "missing .env (copy .env.example)"; exit 1; }
[ ! -x ./pre-deploy.sh ] || ./pre-deploy.sh
set -a; . ./.env; set +a
empty=$(grep -E '^[A-Z_]+=$' .env | cut -d= -f1 || true)
[ -z "$empty" ] || { echo "empty values in .env: $empty"; exit 1; }
vars=$(sed -n 's/^\([A-Z_][A-Z_0-9]*\)=.*/$\1/p' .env | tr '\n' ' ')
id=$(python3 -c "import json;print(json.load(open('workflow.json'))['id'])")
was_active=$(docker exec n8n n8n list:workflow --active=true 2>/dev/null | grep -c "^$id|" || true)
for f in credentials workflow; do
  src=$f.tpl.json; [ -f "$src" ] || src=$f.json
  envsubst "$vars" < "$src" | docker exec -i n8n sh -c "cat > /tmp/$f.json"
  docker exec n8n n8n import:$f --input=/tmp/$f.json
  docker exec n8n rm -f /tmp/$f.json
done
[ "$was_active" -eq 0 ] || docker exec n8n n8n publish:workflow --id="$id"
# n8n only loads workflow definitions at startup; the IMAP trigger catches up from its last UID.
docker restart n8n >/dev/null && echo "n8n restarted (workflow was active: $was_active)"
