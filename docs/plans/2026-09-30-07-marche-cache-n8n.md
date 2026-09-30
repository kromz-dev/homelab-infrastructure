# Marché caché TSSR — pipeline n8n

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **REQUIRED SUB-SKILL n8n :** invoquer `n8n-mcp-skills:using-n8n-mcp-skills` avant toute action n8n, puis les skills spécialisées qu'elle indique (`n8n-workflow-patterns`, `n8n-node-configuration`, `n8n-expression-syntax`, `n8n-error-handling`, `n8n-code-javascript`). Valider chaque workflow avec `validate_workflow` **avant** de le déployer.

**Goal:** Produire et tenir à jour, dans Notion, une liste d'entreprises toulousaines qui embauchent en informatique — avec leurs dirigeants, un contact vérifié et un niveau de confiance — pour alimenter les candidatures spontanées en alternance TSSR.

**Architecture:** Un workflow n8n unique, déclenché par un cron hebdomadaire, qui enchaîne : La Bonne Boîte (5 codes ROME) → dédoublonnage sur le SIRET contre ce qui est déjà dans Notion → enrichissement par le registre officiel des entreprises → recherche et vérification du contact → écriture dans une base Notion dédiée → récapitulatif Telegram. **Tout vit dans n8n** ; aucun code Python, aucune tâche planifiée sur l'hôte.

**Tech Stack:** n8n 2.41.4 (LXC 102), nœuds Schedule Trigger, HTTP Request, Code, Filter, Split In Batches, Notion, Telegram. APIs publiques françaises. Aucune dépendance nouvelle.

**Spec:** Objectif utilisateur « alternance TSSR à Toulouse » (document du 30/09/2026) — étape bloquante déclarée : « Constituer une liste de 30 entreprises cibles (La Bonne Alternance, ESN toulousaines) ». Décision d'architecture du 30/09/2026 : le cœur de l'automatisation est dans n8n, JobBot n'est qu'une source.

---

## Constat d'état (vérifié le 30/09/2026)

Tout ce qui suit a été testé en direct, pas supposé.

| Fait | Vérification |
|---|---|
| La Bonne Boîte répond **sans aucune clé** | `GET /api/v2/search?rome=M1801&citycode=31555&distance=40` → HTTP 200, 70 établissements |
| Volume total autour de Toulouse | M1801=74, M1805=78, M1802=66, M1810=15, I1401=15 à 60 km |
| Le champ `email` est un **drapeau**, pas une adresse | Renvoie `"yes"` ; `phone` et `website` sont vides |
| Le registre donne les **dirigeants nommés** | `recherche-entreprises.api.gouv.fr` → « GUILLAUME MARTIN — Président de SAS » |
| Le registre ne donne **pas** le site web | Champ `siege.site_web` → `None` |
| Le site d'une entreprise donne une **vraie adresse** | `pictarine.com` → `mailto:contact@pictarine.com` sur l'accueil et les mentions légales |
| La page équipe donne les **décideurs** | `pictarine.com/team` → Elodie (Chief People Officer), Benjamin (Head of Engineering) |
| La vérification DNS fonctionne | `dig MX pictarine.com` → Google Workspace ; `dig` présent dans le LXC 102 |
| Les annonces **ne contiennent pas** d'adresses | 0 sur 31 annonces en base : les sites d'annonces les retirent |
| n8n possède déjà Groq, Telegram et Gmail IMAP | `n8n export:credentials` |
| n8n **n'a aucun accès Notion** | Aucun credential Notion ; `NOTION_DATABASE_ID` jamais renseigné |
| OpenStreetMap n'est pas fiable pour le site web | Overpass → HTTP 504 sous charge |

## Prérequis utilisateur (à faire avant la tâche 2)

Sans ces deux éléments, le pipeline ne peut pas écrire son résultat. Environ 15 minutes.

1. **Jeton d'intégration Notion.** Sur <https://www.notion.so/my-integrations>, créer une intégration interne (nom : `n8n homelab`), copier le jeton `ntn_…`. Puis, dans Notion, ouvrir la page qui contiendra la base et la partager avec cette intégration (menu `…` → `Connexions` → `n8n homelab`). **Sans ce partage, l'API renvoie 404 même avec un jeton valide.**
2. **Fournisseur de recherche web**, pour trouver le nom de domaine d'une entreprise à partir de sa raison sociale. C'est le seul maillon qu'aucune API publique française ne couvre — vérifié : le registre ne donne pas le site. Choisir l'un des deux :
   - **Brave Search API** — offre gratuite, ~2 000 requêtes/mois, clé immédiate sur <https://brave.com/search/api/>. **Recommandé** : le quota couvre très largement l'usage.
   - **Google Programmable Search** — 100 requêtes/jour gratuites, demande une clé API et un identifiant de moteur.

   Volume réel attendu : environ 250 requêtes au premier passage, puis quelques dizaines par semaine.

3. *(Optionnel, recommandé)* **Compte francetravail.io**, noté depuis le 17/09/2026 dans `jobbot/progress/A_FAIRE.md`. L'API « Offres d'emploi v2 » expose un champ de contact du recruteur que les pages web masquent. Utile au plan 08, pas bloquant ici.

## Global Constraints

- **Tout dans n8n.** Aucun script Python, aucune entrée cron sur l'hôte Proxmox, aucun planificateur interne. Si une étape semble exiger du code, elle tient dans un nœud Code JavaScript.
- Le workflow est versionné dans ce dépôt sous `docker-stacks/automation/workflows/marche-cache/`, suivant la convention des workflows existants : `workflow.json` (identifiants de credentials uniquement), `credentials.tpl.json` avec des `${VARIABLES}`, `.env.example` versionné, `.env` **jamais** versionné.
- Déploiement par `/opt/automation/deploy-workflow.sh marche-cache`. Le workflow **n'est pas activé** par le script : l'activer depuis l'interface après un essai manuel concluant.
- **Politesse réseau, non négociable.** Au plus 1 requête à la fois vers un même domaine, 1 seconde entre deux requêtes, 3 tentatives maximum avec attente croissante sur 429 et 5xx. En-tête `User-Agent: recherche-alternance/1.0 (usage personnel)`. Tout nœud HTTP a un `timeout` explicite.
- **On ne suppose jamais une adresse e-mail.** Aucune construction du type `prenom.nom@domaine`. Aucune sonde SMTP `RCPT TO` : elle partirait de l'IP résidentielle depuis laquelle l'utilisateur postule et risquerait de la faire blacklister. Seules les adresses **publiées par l'entreprise** sont retenues.
- **Aucun scraping de LinkedIn.** Conditions d'utilisation, blocage actif, et risque de restriction du compte dont l'utilisateur a besoin pour chercher son alternance.
- **Ne jamais modifier ni supprimer une ligne Notion existante.** La base « Candidatures IT » contient 2 candidatures saisies à la main. Ce pipeline écrit dans une base **distincte** et ne fait que des créations.
- Tous les libellés visibles (propriétés Notion, messages Telegram) en français.
- Un workflow qui échoue doit être **bruyant** : nœud `Error Trigger` relié à Telegram, comme le fait déjà `mail-triage`.

## Review Focus

Cinq situations que la spec implique et qu'aucune étape n'exerce spontanément. Chacune est rattachée à la tâche qui doit la traiter.

1. **Une entreprise déjà présente dans Notion** — le workflow relancé deux fois de suite ne doit créer aucun doublon. C'est la crainte explicite de l'utilisateur. → Tâche 3.
2. **Une entreprise administrativement fermée** — le registre expose `etat_administratif` ; une entreprise cessée ne doit jamais atterrir dans la liste. → Tâche 4.
3. **Un site web injoignable, en erreur, ou qui répond en 30 secondes** — le pipeline doit continuer avec les autres entreprises, pas s'arrêter. → Tâche 5.
4. **Un domaine sans enregistrement MX** — il n'accepte pas de courrier ; l'entreprise doit être marquée « contact introuvable », jamais dotée d'une adresse inventée. → Tâche 5.
5. **La Bonne Boîte renvoie 0 résultat ou une erreur pour un code ROME** — les quatre autres codes doivent continuer d'être traités. → Tâche 2.

## File Structure

| Fichier | Rôle |
|---|---|
| `docker-stacks/automation/workflows/marche-cache/workflow.json` (créé) | Le workflow n8n complet |
| `docker-stacks/automation/workflows/marche-cache/credentials.tpl.json` (créé) | Credentials Notion et Brave avec placeholders |
| `docker-stacks/automation/workflows/marche-cache/.env.example` (créé) | Noms des variables attendues |
| `docker-stacks/automation/README.md` (modifié) | Documentation du workflow |
| `docs/plans/2026-09-30-07-marche-cache-n8n.md` (ce fichier) | Le plan |

---

### Task 1: Base Notion « Entreprises cibles » et credentials

**Files:**
- Create: `docker-stacks/automation/workflows/marche-cache/.env.example`
- Create: `docker-stacks/automation/workflows/marche-cache/credentials.tpl.json`

**Interfaces:**
- Produces: une base Notion dédiée, son identifiant, et deux credentials utilisables dans n8n.

- [ ] **Step 1: Créer la base Notion, séparée de « Candidatures IT »**

Dans Notion, créer une base de données nommée **« Entreprises cibles — TSSR »**, avec exactement ces propriétés :

| Propriété | Type | Rôle |
|---|---|---|
| `Entreprise` | Titre | Raison sociale |
| `SIRET` | Texte | **La clé anti-doublon.** Identifiant unique de l'établissement |
| `Ville` | Texte | Commune |
| `Distance` | Nombre | Kilomètres depuis Toulouse |
| `Effectif` | Texte | Tranche de salariés |
| `Secteur` | Texte | Libellé NAF |
| `Potentiel` | Nombre | Score d'embauche de La Bonne Boîte |
| `Dirigeants` | Texte | Noms et fonctions issus du registre |
| `Décideurs` | Texte | Personnes et rôles trouvés sur le site |
| `Contact` | Email | L'adresse publiée, **jamais devinée** |
| `Confiance` | Sélection | `Vérifié` · `Probable` · `Introuvable` |
| `Site` | URL | Domaine trouvé |
| `Statut` | Sélection | `À contacter` · `Candidature envoyée` · `Relance à faire` · `Entretien` · `En attente` · `Accepté` · `Refusé` |
| `Ajouté le` | Date | Date de création par le workflow |

> Les valeurs de `Statut` reprennent exactement celles que l'utilisateur a définies dans son document d'objectif. Ne pas les inventer.

Récupérer l'identifiant de la base : ouvrir la base en pleine page, l'URL contient `notion.so/<espace>/<DATABASE_ID>?v=…`. Le `DATABASE_ID` fait 32 caractères hexadécimaux.

Partager la base avec l'intégration `n8n homelab` (menu `…` → `Connexions`).

- [ ] **Step 2: Écrire `.env.example`**

`docker-stacks/automation/workflows/marche-cache/.env.example` :

```sh
# Notion — jeton d'intégration interne (https://www.notion.so/my-integrations)
NOTION_TOKEN=
# Identifiant de la base « Entreprises cibles — TSSR » (32 caractères hex)
NOTION_DATABASE_ID=
# Recherche web, pour trouver le domaine d'une entreprise (https://brave.com/search/api/)
BRAVE_API_KEY=
# Telegram — mêmes valeurs que le workflow mail-triage
TELEGRAM_CHAT_ID=
```

- [ ] **Step 3: Écrire `credentials.tpl.json`**

Deux credentials de type `httpHeaderAuth`, cohérents avec le style du dépôt (le workflow `jobbot-alert` utilise déjà ce type pour Groq et Notion) :

```json
[
  {
    "id": "notion-marche-cache",
    "name": "Notion — Entreprises cibles",
    "type": "httpHeaderAuth",
    "data": { "name": "Authorization", "value": "Bearer ${NOTION_TOKEN}" }
  },
  {
    "id": "brave-search",
    "name": "Brave Search API",
    "type": "httpHeaderAuth",
    "data": { "name": "X-Subscription-Token", "value": "${BRAVE_API_KEY}" }
  }
]
```

- [ ] **Step 4: Vérifier l'accès Notion avant d'aller plus loin**

Remplir `.env` sur le serveur (`/opt/automation/workflows/marche-cache/.env`, `chmod 600`), puis :

```bash
sudo pct exec 102 -- sh -c 'set -a; . /opt/automation/workflows/marche-cache/.env; set +a;
curl -s -o /dev/null -w "Notion HTTP %{http_code}\n" \
  -X POST "https://api.notion.com/v1/databases/$NOTION_DATABASE_ID/query" \
  -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" -d "{\"page_size\":1}"' 2>&1 | cat
```

Attendu : `Notion HTTP 200`. Un `404` signifie que la base n'a pas été partagée avec l'intégration — c'est l'erreur la plus fréquente.

- [ ] **Step 5: Commit**

```bash
cd /home/devkram/homelab-infrastructure
git add docker-stacks/automation/workflows/marche-cache/.env.example \
        docker-stacks/automation/workflows/marche-cache/credentials.tpl.json
git commit -m "feat(automation): credentials et variables du workflow marché caché

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Collecte La Bonne Boîte, tolérante aux pannes

**Files:**
- Create: `docker-stacks/automation/workflows/marche-cache/workflow.json`

**Interfaces:**
- Produces: une liste d'établissements, chacun avec `siret, nom, ville, citycode, lat, lon, effectif, naf_label, potentiel`.

- [ ] **Step 1: Invoquer les skills n8n**

Avant de composer le moindre nœud, invoquer `n8n-mcp-skills:using-n8n-mcp-skills`, puis `n8n-workflow-patterns` (architecture) et `n8n-node-configuration` (paramètres). Utiliser `search_nodes` et `get_node` plutôt que d'écrire la configuration de mémoire : la surface de n8n change entre versions.

- [ ] **Step 2: Déclencheur et liste des recherches**

Nœud `Schedule Trigger`, hebdomadaire, lundi 7h00 (Europe/Paris).

Puis un nœud `Code` (mode « Run Once for All Items ») qui produit une ligne par code ROME :

```javascript
// 5 codes ROME couvrant les métiers systèmes, réseaux et support.
// Volumes constatés le 30/09/2026 à 60 km de Toulouse : 74, 78, 66, 15, 15.
const ROMES = [
  { code: 'M1801', libelle: 'Administration de systèmes d\'information' },
  { code: 'M1802', libelle: 'Expertise et support en systèmes d\'information' },
  { code: 'M1805', libelle: 'Études et développement informatique' },
  { code: 'M1810', libelle: 'Production et exploitation de systèmes d\'information' },
  { code: 'I1401', libelle: 'Maintenance informatique et bureautique' },
];
const CITYCODE = '31555';   // Toulouse
const DISTANCE = 60;        // km
return ROMES.map(r => ({ json: { ...r, citycode: CITYCODE, distance: DISTANCE } }));
```

- [ ] **Step 3: Interroger La Bonne Boîte, sans laisser une panne tout arrêter**

Nœud `HTTP Request` :

- Méthode `GET`, URL :
  `=https://labonneboite.francetravail.fr/api/v2/search?rome={{ $json.code }}&citycode={{ $json.citycode }}&distance={{ $json.distance }}&page=1&page_size=100&sort_by=romes.hiring_potential&sort_direction=desc`
- En-tête `User-Agent: recherche-alternance/1.0 (usage personnel)`
- `timeout` : 20000
- `batching` : `batchSize: 1`, `batchInterval: 1000` — une requête par seconde.
- **`onError: continueRegularOutput`** et `retryOnFail: true`, `maxTries: 3`, `waitBetweenTries: 2000`.

> C'est le point 5 du Review Focus : si un code ROME échoue, les quatre autres doivent aboutir. Sans `onError`, n8n arrête tout le workflow à la première erreur. Consulter la skill `n8n-error-handling` avant de câbler ce nœud.

- [ ] **Step 4: Aplatir et dédoublonner sur le SIRET**

Nœud `Code` (« Run Once for All Items ») :

```javascript
// Un même établissement peut remonter sur plusieurs codes ROME : on garde
// celui qui a le meilleur potentiel d'embauche.
const parSiret = new Map();
for (const item of $input.all()) {
  const rome = item.json.rome || '';
  for (const e of (item.json.items || [])) {
    if (!e.siret) continue;
    const existant = parSiret.get(e.siret);
    const potentiel = Number(e.hiring_potential) || 0;
    if (existant && existant.potentiel >= potentiel) {
      if (!existant.romes.includes(e.rome)) existant.romes.push(e.rome);
      continue;
    }
    parSiret.set(e.siret, {
      siret: e.siret,
      nom: e.company_name || '',
      ville: e.city || '',
      citycode: e.citycode || '',
      lat: e.location?.lat ?? null,
      lon: e.location?.lon ?? null,
      effectif: [e.headcount_min, e.headcount_max].filter(Boolean).join('-'),
      naf_label: e.naf_label || '',
      potentiel: Math.round(potentiel * 10) / 10,
      romes: existant ? existant.romes : [e.rome],
    });
  }
}
return [...parSiret.values()].map(json => ({ json }));
```

- [ ] **Step 5: Essai manuel**

Exécuter le workflow à la main depuis l'interface n8n. Attendu : environ 200 à 250 établissements distincts, aucun SIRET en double.

Vérifier aussi le cas d'erreur : remplacer temporairement un code ROME par une valeur invalide (`ZZZZZ`), réexécuter, et constater que les quatre autres remontent quand même leurs résultats.

- [ ] **Step 6: Commit**

```bash
git add docker-stacks/automation/workflows/marche-cache/workflow.json
git commit -m "feat(automation): collecte La Bonne Boîte sur 5 codes ROME

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Ne jamais créer un doublon dans Notion

C'est la crainte explicite de l'utilisateur, et la cause du problème qu'on répare : l'ancien pont poussait vers Notion sans jamais vérifier l'existant.

**Files:**
- Modify: `docker-stacks/automation/workflows/marche-cache/workflow.json`

**Interfaces:**
- Consumes: la liste d'établissements de la tâche 2.
- Produces: uniquement les établissements **absents** de Notion.

- [ ] **Step 1: Lire les SIRET déjà connus**

Nœud `HTTP Request`, branché **en parallèle** de la collecte (pas en série) :

- `POST https://api.notion.com/v1/databases/{{ $env.NOTION_DATABASE_ID }}/query`
- Credential `Notion — Entreprises cibles`
- En-têtes `Notion-Version: 2022-06-28`, `Content-Type: application/json`
- Corps : `{ "page_size": 100 }`
- `timeout` : 15000

La réponse Notion est paginée : tant que `has_more` vaut `true`, il faut relancer avec `start_cursor`. Câbler une boucle avec un nœud `If` sur `{{ $json.has_more }}` qui repasse dans le nœud de requête avec `"start_cursor": "{{ $json.next_cursor }}"`.

> Ne pas sauter la pagination. Dès 100 entreprises, une requête unique en oublierait et recréerait des doublons — exactement ce qu'on veut éviter.

- [ ] **Step 2: Construire l'ensemble des SIRET connus**

Nœud `Code` :

```javascript
const connus = new Set();
for (const item of $input.all()) {
  for (const page of (item.json.results || [])) {
    const p = page.properties?.SIRET;
    const valeur = (p?.rich_text || []).map(t => t.plain_text).join('').trim();
    if (valeur) connus.add(valeur);
  }
}
return [{ json: { connus: [...connus] } }];
```

- [ ] **Step 3: Filtrer**

Nœud `Code` (« Run Once for All Items ») qui croise les deux branches :

```javascript
const connus = new Set($('SIRET connus').first().json.connus || []);
const nouveaux = $('Dédoublonner').all().filter(i => !connus.has(i.json.siret));
console.log(`${nouveaux.length} nouvelles entreprises sur ${$('Dédoublonner').all().length}`);
return nouveaux;
```

> Adapter les noms entre `$('…')` aux noms réels des nœuds. La skill `n8n-expression-syntax` explique cette syntaxe de référence entre nœuds — la consulter, c'est la source d'erreur la plus fréquente.

- [ ] **Step 4: Test du Review Focus n°1 — l'idempotence**

Exécuter le workflow **deux fois de suite**, à la main.

- Premier passage : N entreprises créées dans Notion.
- Second passage, immédiatement après : **0 création**, et le journal du nœud affiche `0 nouvelles entreprises sur ~250`.

Vérifier dans Notion que le nombre total de lignes n'a pas bougé entre les deux passages. **Si une seule ligne a été dupliquée, s'arrêter et corriger avant de continuer.**

- [ ] **Step 5: Commit**

```bash
git add docker-stacks/automation/workflows/marche-cache/workflow.json
git commit -m "feat(automation): garde-fou anti-doublon sur le SIRET avant écriture Notion

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Enrichissement par le registre officiel

**Files:**
- Modify: `docker-stacks/automation/workflows/marche-cache/workflow.json`

**Interfaces:**
- Produces: chaque entreprise gagne `dirigeants` (texte), `date_creation`, `etat_administratif`, `effectif_registre`.

- [ ] **Step 1: Limiter le débit**

Nœud `Split In Batches`, `batchSize: 1`. Tout ce qui suit s'exécute entreprise par entreprise, ce qui rend les limites de débit tenables et les erreurs isolables.

- [ ] **Step 2: Interroger le registre**

Nœud `HTTP Request` :

- `GET https://recherche-entreprises.api.gouv.fr/search?q={{ $json.siret }}&per_page=1`
- `timeout` : 15000, `batchInterval` : 1000
- `onError: continueRegularOutput`, `retryOnFail: true`, `maxTries: 3`

Cette API est publique et sans clé — vérifié le 30/09/2026.

- [ ] **Step 3: Extraire les dirigeants et écarter les entreprises fermées**

Nœud `Code` (« Run Once for Each Item ») :

```javascript
const base = $('Filtrer les nouvelles').item.json;
const r = ($json.results || [])[0] || {};

const dirigeants = (r.dirigeants || [])
  .filter(d => d.type_dirigeant === 'personne physique')
  .map(d => `${(d.prenoms || '').trim()} ${(d.nom || '').trim()} — ${d.qualite || ''}`.trim())
  .slice(0, 4)
  .join(' · ');

return [{ json: {
  ...base,
  dirigeants,
  date_creation: r.date_creation || '',
  etat_administratif: r.etat_administratif || '',
  effectif_registre: r.tranche_effectif_salarie || '',
} }];
```

- [ ] **Step 4: Filtrer les entreprises cessées — Review Focus n°2**

Nœud `Filter` : garder uniquement `{{ $json.etat_administratif }}` **égal à** `A` (actif).

Une entreprise cessée qui remonte de La Bonne Boîte (dont l'index a du retard) ne doit jamais atterrir dans la liste : écrire à une société fermée est une perte de temps pure.

- [ ] **Step 5: Vérifier sur un cas réel**

Exécuter et contrôler qu'au moins une entreprise porte des dirigeants nommés. Référence connue : le SIRET `84484409200248` (Econocom Services & Solutions, Labège) renvoie « ANGEL BENGUIGUI DIAZ — Président de SAS ».

- [ ] **Step 6: Commit**

```bash
git add docker-stacks/automation/workflows/marche-cache/workflow.json
git commit -m "feat(automation): dirigeants et état administratif depuis le registre

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Le nœud contact — trouver, jamais deviner

**Files:**
- Modify: `docker-stacks/automation/workflows/marche-cache/workflow.json`

**Interfaces:**
- Produces: `site`, `contact` (email publié ou vide), `decideurs` (personnes et rôles), `confiance` (`Vérifié` / `Probable` / `Introuvable`).

- [ ] **Step 1: Trouver le domaine**

Nœud `HTTP Request` vers Brave Search :

- `GET https://api.search.brave.com/res/v1/web/search?q={{ encodeURIComponent($json.nom + ' ' + $json.ville + ' site officiel') }}&count=5`
- Credential `Brave Search API`, en-tête `Accept: application/json`
- `timeout` : 15000, `onError: continueRegularOutput`

Puis un nœud `Code` qui retient le premier résultat dont le domaine n'est **pas** un annuaire :

```javascript
// Les annuaires d'entreprises polluent les résultats : ils ressortent avant
// le site officiel. Constaté le 30/09/2026 sur des recherches réelles.
const ANNUAIRES = [
  'societe.com', 'verif.com', 'pappers.fr', 'infogreffe.fr', 'annuaire-entreprises',
  'linkedin.com', 'facebook.com', 'indeed.', 'hellowork', 'glassdoor',
  'lejournaldesentreprises', 'bodacc', 'data.gouv.fr', 'xerfi.com', 'topograph',
];
const base = $('Écarter les entreprises fermées').item.json;
const resultats = $json.web?.results || [];
let site = '';
for (const r of resultats) {
  const url = r.url || '';
  const hote = (() => { try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return ''; } })();
  if (!hote || ANNUAIRES.some(a => hote.includes(a))) continue;
  site = hote;
  break;
}
return [{ json: { ...base, site } }];
```

- [ ] **Step 2: Vérifier que le domaine reçoit du courrier — Review Focus n°4**

n8n n'a pas de nœud DNS. Utiliser un service DNS-over-HTTPS public, sans clé :

Nœud `HTTP Request` : `GET https://dns.google/resolve?name={{ $json.site }}&type=MX`, `timeout` 10000, `onError: continueRegularOutput`.

Puis nœud `Code` :

```javascript
const base = $('Trouver le domaine').item.json;
// Status 0 = NOERROR. La présence d'une réponse de type 15 (MX) prouve que
// le domaine est configuré pour recevoir du courrier.
const mx = ($json.Answer || []).some(a => a.type === 15);
return [{ json: { ...base, mx } }];
```

Si `mx` vaut `false`, l'entreprise part directement vers la sortie « contact introuvable » : inutile de scraper un domaine qui ne reçoit pas de mail.

- [ ] **Step 3: Récupérer l'accueil du site**

Nœud `HTTP Request` :

- `GET https://{{ $json.site }}`
- `responseFormat: text`
- En-tête `User-Agent: recherche-alternance/1.0 (usage personnel)`
- **`timeout` : 12000** — Review Focus n°3 : un site lent ne doit pas bloquer les 249 autres.
- `onError: continueRegularOutput`, `retryOnFail: false` (inutile d'insister sur un site en panne)
- `batchInterval` : 1000

- [ ] **Step 4: Extraire adresses et pages à suivre**

Nœud `Code` :

```javascript
const base = $('Vérifier MX').item.json;
const html = typeof $json.data === 'string' ? $json.data : '';

const RX_MAIL = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
const mails = [...new Set((html.match(RX_MAIL) || []))]
  .filter(m => !/\.(png|jpe?g|gif|svg|webp|css|js)$/i.test(m))
  .filter(m => m.toLowerCase().endsWith('@' + base.site.toLowerCase()));

// Pages qui portent habituellement les contacts et les équipes.
const RX_LIEN = /href="([^"]*(?:contact|mention|legal|equipe|team|propos|about|recrut|career|job)[^"]*)"/gi;
const suites = [...new Set([...html.matchAll(RX_LIEN)].map(m => m[1]))]
  .filter(h => !h.startsWith('mailto:') && !/\.(png|jpe?g|gif|svg|pdf)$/i.test(h))
  .slice(0, 4);

return [{ json: { ...base, mails, suites } }];
```

> Le filtre sur le domaine de l'entreprise est important : les sites embarquent des adresses de prestataires, d'agences web et d'outils tiers. Seule une adresse **du domaine de l'entreprise** est un contact valable.

- [ ] **Step 5: Suivre les pages contact, mentions légales et équipe**

Nœud `HTTP Request` en boucle sur `suites` (au plus 4 pages), mêmes réglages qu'à l'étape 3. Puis un nœud `Code` qui fusionne :

```javascript
const base = $('Extraire accueil').item.json;
const RX_MAIL = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
// Rôles qui décident d'une alternance en systèmes et réseaux.
const RX_ROLE = /\b(DSI|RSSI|CTO|CEO|DRH|Chief People Officer|Head of (?:Engineering|IT|People)|Responsable (?:informatique|infrastructure|technique|RH|recrutement)|Directeur (?:technique|informatique|des systèmes))\b/gi;

let mails = [...(base.mails || [])];
let roles = [];
for (const item of $input.all()) {
  const html = typeof item.json.data === 'string' ? item.json.data : '';
  mails.push(...(html.match(RX_MAIL) || []));
  roles.push(...(html.match(RX_ROLE) || []));
}
mails = [...new Set(mails)]
  .filter(m => m.toLowerCase().endsWith('@' + base.site.toLowerCase()))
  .filter(m => !/\.(png|jpe?g|gif|svg|css|js)$/i.test(m));

// Une adresse de recrutement vaut mieux qu'une adresse générale.
const RANG = m => {
  const l = m.toLowerCase();
  if (/(recrut|rh|job|career|talent|emploi)/.test(l)) return 0;
  if (/(contact|hello|bonjour)/.test(l)) return 1;
  if (/(info|accueil)/.test(l)) return 2;
  return 3;
};
mails.sort((a, b) => RANG(a) - RANG(b));

const contact = mails[0] || '';
const confiance = contact ? 'Vérifié' : (base.mx ? 'Probable' : 'Introuvable');

return [{ json: {
  ...base,
  contact,
  autres_contacts: mails.slice(1, 4).join(' · '),
  decideurs: [...new Set(roles)].slice(0, 6).join(' · '),
  confiance,
} }];
```

> **`confiance` dit la vérité et rien d'autre.** `Vérifié` : une adresse publiée par l'entreprise a été trouvée. `Probable` : le domaine reçoit du courrier mais aucune adresse n'est publiée — à chercher à la main. `Introuvable` : ni domaine exploitable, ni MX. On n'écrit jamais d'adresse construite dans ce champ.

- [ ] **Step 6: Vérifier sur le cas de référence**

Référence mesurée le 30/09/2026 : `pictarine.com` doit donner `contact@pictarine.com`, `confiance = Vérifié`, MX présent, et des rôles parmi `Chief People Officer` et `Head of Engineering`.

Vérifier aussi les trois cas dégradés :
- un domaine inexistant → `Introuvable`, le workflow continue ;
- un site qui ne répond pas dans les 12 secondes → l'entreprise ressort avec `Probable`, le workflow continue ;
- une entreprise dont le site n'expose aucune adresse → `Probable`, jamais une adresse inventée.

- [ ] **Step 7: Écrire dans Notion et récapituler**

Nœud `HTTP Request` : `POST https://api.notion.com/v1/pages`, credential Notion, corps construit par un nœud `Code` qui reprend la structure de propriétés de la tâche 1 (`Entreprise` en `title`, `SIRET`/`Ville`/`Dirigeants`/`Décideurs` en `rich_text`, `Contact` en `email`, `Confiance`/`Statut` en `select`, `Potentiel`/`Distance` en `number`, `Site` en `url`, `Ajouté le` en `date`).

`Statut` est initialisé à `À contacter`.

Puis un nœud `Telegram` avec le récapitulatif :

```
🏢 Marché caché TSSR — <N> nouvelles entreprises
✅ <x> avec contact vérifié
🔍 <y> à chercher à la main
📍 Top potentiel : <nom> (<ville>, <potentiel>)
```

Enfin, un `Error Trigger` relié à un second nœud Telegram, sur le modèle de `mail-triage`.

- [ ] **Step 8: Valider le workflow avant de déployer**

```
validate_workflow(workflow.json)
```

Corriger tout ce que la validation signale. Consulter `n8n-validation-expert` pour distinguer les vraies erreurs des faux positifs.

- [ ] **Step 9: Déployer, exécuter, et vérifier l'idempotence une dernière fois**

```bash
sudo pct exec 102 -- /opt/automation/deploy-workflow.sh marche-cache 2>&1 | cat
```

Exécuter à la main depuis l'interface. Puis **réexécuter immédiatement** et vérifier que le nombre de lignes Notion n'a pas bougé.

Vérifier enfin que n8n et `mail-triage` sont intacts :

```bash
curl -s -o /dev/null -w "n8n HTTP %{http_code}\n" http://192.168.1.151:5678/healthz
```

- [ ] **Step 10: Documenter et commiter**

Ajouter à `docker-stacks/automation/README.md` :

```markdown
- `marche-cache` — entreprises toulousaines qui embauchent en informatique (La Bonne Boîte,
  5 codes ROME), enrichies par le registre des entreprises et par un contact vérifié sur
  leur site. Écrit dans la base Notion « Entreprises cibles — TSSR », sans jamais créer de
  doublon (clé : le SIRET) ni deviner une adresse e-mail.
```

```bash
git add docker-stacks/automation/workflows/marche-cache/ docker-stacks/automation/README.md
git commit -m "feat(automation): workflow marché caché avec contact vérifié

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Deuxième source — l'annuaire du cluster Digital113

La Bonne Boîte est une **estimation statistique** de propension à embaucher. Digital113 est une **liste choisie** : des entreprises du numérique d'Occitanie qui ont payé une adhésion à un cluster local. Population plus petite, mais mieux ciblée, et qui rattrape les entreprises que l'indice statistique manque.

**Files:**
- Modify: `docker-stacks/automation/workflows/marche-cache/workflow.json`

**Interfaces:**
- Produces: des entreprises au même format que la tâche 2, injectées **avant** le dédoublonnage de la tâche 3 — elles passent donc par le même garde-fou anti-doublon et le même nœud contact.

- [ ] **Step 1: Récupérer la liste des adhérents**

Nœud `HTTP Request` : `GET https://www.digital113.fr/adherents`, `responseFormat: text`, `timeout` 20000, `User-Agent` du projet, `onError: continueRegularOutput`.

Vérifié le 30/09/2026 : la page renvoie environ 133 Ko de HTML **statique** (pas de chargement dynamique), et contient les noms d'adhérents en clair.

- [ ] **Step 2: Extraire les raisons sociales**

Nœud `Code`. Attention : la page contient aussi des noms de communes (`BALMA`, `BLAGNAC`, `CAPDENAC`…) et des éléments de navigation (`Accueil`, `Agenda`) qu'il faut écarter.

```javascript
const html = typeof $json.data === 'string' ? $json.data : '';
const NAVIGATION = new Set(['ACCUEIL', 'AGENDA', 'CONTACT', 'ADHERENTS', 'ACTUALITES', 'APPELEZ-NOUS']);
// Communes d'Occitanie qui apparaissent comme localisation, pas comme adhérent.
const COMMUNES = new Set(['BALMA','BLAGNAC','CAPDENAC','TOULOUSE','MONTPELLIER','LABEGE','COLOMIERS','NIMES','PERPIGNAN','ALBI','CASTRES','RODEZ','AUCH','TARBES','MURET','SETE','BEZIERS','CARCASSONNE']);

const noms = [...new Set(
  html.split(/<[^>]*>/)
      .map(s => s.trim())
      .filter(s => /^[A-Z0-9][A-Za-z0-9&.\-' ]{2,40}$/.test(s))
)]
  .filter(n => !NAVIGATION.has(n.toUpperCase()))
  .filter(n => !COMMUNES.has(n.toUpperCase()));

return noms.map(nom => ({ json: { nom, source: 'Digital113' } }));
```

- [ ] **Step 3: Retrouver le SIRET de chaque adhérent**

Le dédoublonnage de la tâche 3 repose sur le SIRET ; il faut donc le résoudre depuis la raison sociale.

Nœud `HTTP Request` : `GET https://recherche-entreprises.api.gouv.fr/search?q={{ encodeURIComponent($json.nom) }}&departement=31&per_page=1`, `timeout` 15000, `batchInterval` 1000, `onError: continueRegularOutput`.

Puis un nœud `Code` qui ne garde que les correspondances **sûres**, et jette les autres :

```javascript
const base = $('Extraire adhérents').item.json;
const r = ($json.results || [])[0];
// Sans correspondance nette, on jette : une mauvaise entreprise dans la liste
// coûte plus cher qu'une entreprise manquante.
if (!r || r.etat_administratif !== 'A') return [];

const norm = s => (s || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
if (!norm(r.nom_complet).includes(norm(base.nom)) && !norm(base.nom).includes(norm(r.nom_complet))) return [];

const siege = r.siege || {};
return [{ json: {
  siret: siege.siret || '',
  nom: r.nom_complet || base.nom,
  ville: siege.libelle_commune || '',
  citycode: siege.commune || '',
  lat: siege.latitude ? Number(siege.latitude) : null,
  lon: siege.longitude ? Number(siege.longitude) : null,
  effectif: r.tranche_effectif_salarie || '',
  naf_label: siege.activite_principale || '',
  potentiel: 0,            // pas d'indice statistique pour cette source
  romes: [],
  source: 'Digital113',
} }];
```

- [ ] **Step 4: Fusionner avec la branche La Bonne Boîte**

Nœud `Merge` en mode `append`, **avant** le filtre anti-doublon de la tâche 3. Les entreprises présentes dans les deux sources sont éliminées par le SIRET, comme les autres.

Ajouter `Source` (type Texte) à la base Notion pour distinguer l'origine.

- [ ] **Step 5: Vérifier**

Exécuter à la main. Attendu : des entreprises supplémentaires par rapport au passage précédent, aucune commune ni élément de navigation dans la liste, aucun doublon avec La Bonne Boîte.

Contrôler **à l'œil** une dizaine de lignes issues de Digital113 : la correspondance nom → SIRET est l'étape la plus risquée de tout ce plan. Si plus d'une ligne sur dix est fausse, durcir le test de correspondance avant de continuer.

- [ ] **Step 6: Commit**

```bash
git add docker-stacks/automation/workflows/marche-cache/workflow.json
git commit -m "feat(automation): adhérents Digital113 comme seconde source

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Sources : ce qui est automatisable, et ce qui ne l'est pas

Le marché de l'emploi tech passe largement par des canaux communautaires. Tous ne se scrapent pas, et la différence n'est pas technique mais juridique.

**Automatisable, et retenu :**

| Source | État |
|---|---|
| La Bonne Boîte (5 codes ROME) | ✅ vérifié, sans clé — tâche 2 |
| Registre des entreprises | ✅ vérifié, sans clé — tâche 4 |
| Site des entreprises (contact, mentions légales, équipe) | ✅ vérifié — tâche 5 |
| Annuaire Digital113 (~300 adhérents) | ✅ vérifié, HTML statique — tâche 6 |
| Page emploi Digital113 (via Taleez) | à étudier au plan 08 |
| API France Travail et La Bonne Alternance | comptes gratuits à créer — plan 08 |
| Flux RSS des pages carrières | à étudier au plan 08 |

**Non retenu, et ce n'est pas un choix technique :**

- **Discord.** Lire par programme un serveur où l'on est simplement membre exige soit un *bot* invité par l'administrateur du serveur — impossible sur un serveur qu'on a juste rejoint — soit son propre jeton utilisateur, ce que Discord interdit explicitement et sanctionne par la suppression du compte.
- **Slack.** Même situation : un espace communautaire exige qu'un administrateur installe une application.
- **LinkedIn.** Conditions d'utilisation, blocage actif, et risque de restriction du compte.

Dans les trois cas, le risque porte sur **le compte dont l'utilisateur a besoin pour chercher son alternance**. Un robot qui fait bannir son Discord ou son LinkedIn lui coûte infiniment plus cher que les quelques annonces qu'il aurait ramenées.

**Ce que l'automatisation fait à la place :** elle prend en charge tout le travail répétitif — collecte, tri, contacts, brouillons, relances — pour libérer du temps à l'utilisateur, afin qu'il soit présent lui-même sur ces canaux. Être visible dans une communauté tech toulousaine n'est pas une tâche qu'un robot peut déléguer : c'est précisément ce qui ne se délègue pas.

Le plan 11 (rappel hebdomadaire) peut inclure ce rappel dans le message du lundi.

## Suite (plans à écrire après celui-ci)

À écrire seulement une fois ce plan vert, pas avant.

| Plan | Contenu | Dépend de |
|---|---|---|
| 08 — Offres et sources officielles | API France Travail « Offres d'emploi v2 » (dont le champ contact du recruteur) et API La Bonne Alternance, dans n8n. JobBot appelé en HTTP (`POST /api/start`, `GET /api/offers`) pour les 4 sites sans API | 07 |
| 09 — Qualification Groq en 3 étages | Étage 1 : filtre déterministe. Étage 2 : `llama-3.1-8b-instant` en tri binaire. Étage 3 : `llama-3.3-70b-versatile` sur la douzaine retenue. Quota gratuit : ~100 K jetons/jour sur le 70B, ~500 K sur le 8B | 07, 08 |
| 10 — Brouillons Gmail | `imaplib`-équivalent côté n8n : dépôt dans `[Gmail]/Drafts` avec le mot de passe d'application déjà présent. Le mail s'adresse nommément au décideur trouvé en tâche 5, sur l'adresse publiée. **Aucun envoi automatique** | 09 |
| 11 — Relances et rythme | Cron n8n → Telegram le lundi : brouillons en attente, relances dues. Objectif utilisateur : 5 candidatures et 2 relances par semaine | 10 |
| 12 — Retrait du cron hôte | Suppression de `scripts/run-jobbot.sh` et de toute tâche planifiée sur l'hyperviseur : plus rien ne se déclenche en dehors de n8n | 08 |
