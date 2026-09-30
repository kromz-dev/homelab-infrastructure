# Automation stack (LXC 102)

n8n, deployed from this directory to `/opt/automation` on LXC 102.

## Workflows

One directory per workflow under `workflows/`, each with its own `.env`:

| File | In git | Purpose |
|---|---|---|
| `workflow.json` | yes | The workflow. Credentials referenced by id only. |
| `credentials.tpl.json` | yes | Credential definitions with `${VARIABLE}` placeholders. |
| `.env.example` | yes | Names of the variables the workflow needs. |
| `.env` | **no** (server only, `chmod 600`) | The real secrets. |

Deploy (on LXC 102): fill `workflows/<name>/.env`, then

```sh
/opt/automation/deploy-workflow.sh <name>
```

It substitutes the `.env` values into the templates and imports the credentials (encrypted by n8n with `N8N_ENCRYPTION_KEY`) and the workflow. It refuses to run with empty values and does not activate the workflow; activate it from the UI once a test run looks right.

## Workflows available

- `mail-triage` — new mail (IMAP) → Groq judges importance → Telegram notification only if important.
