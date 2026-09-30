#!/usr/bin/env bash
# Run by deploy-workflow.sh before the import. Importing a workflow wipes the IMAP trigger's
# memory of the last mail it handled, and its default UNSEEN search would then notify every
# unread mail again. Move the cutoff to "now".
# ponytail: mail arriving during the ~30 s redeploy window is skipped; keep a UID high-water mark if that matters.
set -euo pipefail
set -a; . ./.env; set +a
next=$(python3 -c "
import imaplib,os
m=imaplib.IMAP4_SSL('imap.gmail.com',993);m.login(os.environ['GMAIL_USER'],os.environ['GMAIL_APP_PASSWORD']);m.select('INBOX',readonly=True)
print(int(m.uid('search',None,'ALL')[1][0].split()[-1])+1)")
sed -i "s/^IMAP_FROM_UID=.*/IMAP_FROM_UID=$next/" .env
echo "IMAP_FROM_UID -> $next"
