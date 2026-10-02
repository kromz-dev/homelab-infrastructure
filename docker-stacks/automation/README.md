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

## JobBot (recherche d'alternance)

`jobbot-tssr` fait tourner [JobBot](https://github.com/kromz-dev/jobbot) avec le profil
`tssr-alternance` : alternance systèmes et réseaux autour de Toulouse (60 km).

- Tableau de bord : http://192.168.1.151:8766
- Données : volume `jobbot_tssr_data` (base SQLite, jamais dans git)
- Profil : `jobbot/profiles/tssr-alternance.json` dans le dépôt JobBot

L'image fige **Python 3.12** : `python-jobspy` (source Indeed) fige `numpy==1.26.3`,
qui ne compile pas sur le Python 3.13 de l'hôte Proxmox. Ne pas faire tourner JobBot
directement sur l'hôte.

Une base de données ne contient qu'un seul profil. Pour en ajouter un, créer un service
avec son propre volume et son propre `JOBBOT_PROFILE`.
