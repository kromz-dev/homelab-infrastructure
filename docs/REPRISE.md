# Reprise — automatisation de recherche d'alternance TSSR

État au 2026-09-30, fin de session. Ce document est le point d'entrée pour un agent qui reprend
le travail sans avoir assisté à la session précédente.

## L'objectif, en une phrase

Trouver une entreprise pour une **alternance TSSR** (technicien supérieur systèmes et réseaux)
autour de Toulouse, rentrée janvier ou septembre 2027. L'étape bloquante déclarée par
l'utilisateur est *trouver l'entreprise*, pas l'organisme de formation.

Son objectif de rythme : **5 candidatures ciblées, 2 contacts directs et 2 relances par semaine.**
L'automatisation existe pour lui rendre du temps, pas pour candidater à sa place.

## Les six règles qui gouvernent tout

Elles viennent de l'utilisateur, certaines après discussion. Ne pas les rouvrir sans qu'il le demande.

1. **Le cœur de l'automatisation vit dans n8n.** Pas dans du Python. Avant d'écrire du code,
   se demander si un nœud n8n le fait. JobBot est une source parmi d'autres, appelée en HTTP.
2. **Zéro doublon, nulle part, à chaque recherche.** C'est sa demande la plus répétée.
   Voir la carte complète des surfaces de doublon dans `docs/plans/2026-09-30-07-marche-cache-n8n.md`.
3. **On ne suppose jamais.** Une adresse e-mail est trouvée là où l'entreprise l'a publiée, ou
   bien le champ reste vide et dit « à chercher à la main ». Jamais de `prenom.nom@domaine`
   construit : un rebond abîme la réputation de la boîte d'envoi au moment où il postule.
   Jamais de sonde SMTP : elle partirait de son IP résidentielle.
4. **Aucun envoi automatique de mail.** L'IA rédige un brouillon dans Gmail, il relit, il envoie.
5. **Les tests existants sont le juge.** Sur JobBot, les 41 tests d'origine ne se modifient pas.
   Si l'un casse, c'est le nouveau code ou la donnée qui a tort.
6. **Pas de scraping de LinkedIn, Discord ni Slack.** Techniquement faisable, mais le risque
   porte sur les comptes dont il a besoin pour chercher son alternance. Tout le reste se scrape :
   sites d'entreprises, mentions légales, pages équipe, annuaires, annonces.

## L'environnement, et ses deux pièges

Hôte Proxmox VE (Dell OptiPlex 3060), trois conteneurs : 101 média, **102 automation**, 103 monitoring.

### Piège 1 — ne jamais lancer Python sur l'hôte

L'hôte est en **Python 3.13**, où `python-jobspy` (source Indeed de JobBot) refuse de s'installer.
Une session précédente, bloquée par ça, avait remplacé l'import par une doublure renvoyant un
tableau vide : **Indeed rendait zéro résultat sans aucune erreur** pendant des jours.

Le code de JobBot vit **dans le LXC 102**, à `/opt/dev/jobbot`, et le même dossier est visible
depuis l'hôte à `/home/devkram/dev/jobbot` grâce à un `lxc.idmap` qui mappe l'UID 1002 à
l'identique des deux côtés.

- **Éditer les fichiers** depuis l'hôte, chemins `/home/devkram/dev/jobbot/...`, outils normaux.
- **Exécuter** uniquement via le raccourci `./jb` à la racine du projet :

```bash
cd /home/devkram/dev/jobbot
./jb pytest -q          # 65 passed, 1 skipped au 30/09/2026
./jb ruff check .       # All checks passed!
JOBBOT_PROFILE=tssr-alternance ./jb pytest -q
```

### Piège 2 — `pct exec` sans `| cat`

Toute commande dans un conteneur passe par `sudo pct exec 102 -- sh -c '...' 2>&1 | cat`.
**Sans le `| cat` final, la sortie est perdue.** Les redirections de fichier depuis l'hôte vers le
conteneur sont bloquées ; utiliser un heredoc (`pct exec 102 -- sh -c 'cat > /chemin' <<'EOF'`)
ou `pct push`.

Docker n'existe **que** dans les conteneurs, pas sur l'hôte.

## Où en est le travail

### Terminé et vérifié

- **JobBot profils de recherche** (dépôt séparé `github.com/kromz-dev/jobbot`, branche
  `feat/profils-tssr`, 8 commits). Le métier cherché est décrit par un fichier JSON
  (`jobbot/profiles/*.json`) : villes, mots-clés, mots de pertinence, signaux et barème. Deux
  profils coexistent, `aide-soignant` (l'historique, qui garde ses 41 tests verts) et
  `tssr-alternance`. Une base ne contient qu'un profil et refuse de s'ouvrir sous un autre.
  **65 tests verts.** Plan : `jobbot/docs/superpowers/plans/2026-09-30-06-*.md`.
- **Service `jobbot-tssr`** déployé dans le LXC 102, port 8766, image Python 3.12, volume dédié.
- **Le cron de root est supprimé.** Plus rien ne se déclenche hors n8n.
- **Documentation du dépôt homelab** remise en accord avec la réalité : LXC 103 était donné pour
  démantelé alors qu'il tourne, et n'était pas documenté.

### En cours à la fin de la session

**Plan 07** — `docs/plans/2026-09-30-07-marche-cache-n8n.md`, le pipeline n8n du marché caché.

**Tâches 1 et 2 faites et vérifiées** (commits `f228314` et `5c6fd7d`) : credentials Notion et
les 5 moteurs versionnés en gabarits, collecte La Bonne Boîte sur les 5 codes ROME, dédoublonnage
par SIRET. Le workflow `marche-cache` est **importé dans n8n mais non activé**. Notion n'a reçu
aucune écriture : toujours exactement 2 lignes. `mail-triage` tourne toujours.

**Mesure réelle : 88 établissements distincts** (248 lignes brutes sur les 5 codes ROME). Une
estimation antérieure du plan annonçait 200 à 250 — elle confondait brut et distinct. Le plan est
corrigé.

**Il reste les tâches 3 à 6** : dédoublonnage à double clé contre Notion, enrichissement par le
registre, nœud contact, annuaire Digital113. **Lire d'abord la section « Pièges du déploiement
n8n » du plan 07** : quatre écueils y sont consignés, dont deux qui casseraient silencieusement
les tâches suivantes (`${VAR}` contre `$env.`, et les noms de nœuds entre `$('…')`).

Avant de reprendre, vérifier l'état réel : `git log --oneline` dans les deux dépôts,
`./jb pytest -q`, et `sudo pct exec 102 -- docker exec n8n n8n list:workflow 2>&1 | cat`.

### Ensuite

| Plan | Contenu |
|---|---|
| 08 | Offres : API France Travail et La Bonne Alternance, JobBot appelé en HTTP. Reprendre le filtre anti-organismes de formation du `stash@{0}` de JobBot |
| — | Ménage n8n : `workflow-jobbot-alert` (« JobBot - Ingestion ») est **actif** mais orphelin — c'est l'ancien pont Python → webhook, plus rien ne l'appelle depuis la suppression du cron. Le désactiver et le supprimer, avec `TEST erreur` et `My workflow`. La CLI ne sait pas supprimer, il faut l'interface |
| 09 | Qualification Groq en 3 étages — voir les quotas plus bas |
| 10 | Brouillons Gmail, jamais d'envoi |
| 11 | Rappel Telegram du lundi : brouillons prêts, relances dues |

## Ce qui est déjà vérifié — ne pas le retester

Tout ceci a été testé en direct le 30/09/2026.

| Élément | Fait vérifié |
|---|---|
| La Bonne Boîte | Répond **sans clé**. À 60 km de Toulouse (`citycode=31555`) : M1801=74, M1802=66, M1805=78, M1810=15, I1401=15 |
| `recherche-entreprises.api.gouv.fr` | Sans clé. Donne les **dirigeants nommés**, l'effectif, l'état administratif. **Ne donne pas** le site web |
| Site d'entreprise | Donne de vraies adresses. Testé : `pictarine.com` → `mailto:contact@pictarine.com` sur l'accueil et les mentions légales |
| Page équipe | Donne les décideurs. Testé : Elodie (Chief People Officer), Benjamin (Head of Engineering) |
| Vérification MX | `dig` présent dans le LXC 102 ; sinon `https://dns.google/resolve?name=<domaine>&type=MX` |
| Annonces des sites d'emploi | **0 adresse sur 31 annonces** — les sites les retirent. Source morte |
| Annuaire Digital113 | `digital113.fr/adherents` — ~300 adhérents en HTML statique, exploitable |
| La Bonne Alternance V1 | **404, route morte.** La nouvelle API demande un compte gratuit |
| OpenStreetMap / Overpass | HTTP 504 sous charge. Pas fiable comme brique principale |
| Notion | Base « Candidatures IT », `d24e8ee1-80ce-4cb6-848c-45e44be4a096`, intégration `n8n-alternance` |

## Notion — le schéma exact

**On écrit dans « Candidatures IT »**, pas dans une base séparée : son `Statut` contient
« À analyser » et « À candidater », elle porte tout l'entonnoir. Nouveaux prospects → `À analyser`.

`Statut` : `À analyser` · `À candidater` · `Candidature envoyée` · `Relance à faire` ·
`Entretien` · `En attente` · `Accepté` · `Refusé` · `Abandonné`

`Source` : `La Bonne Alternance` · `France Travail` · `Indeed` · `HelloWork` · `LinkedIn` ·
`Site entreprise` · `Candidature spontanée` · `Réseau`

`Adéquation avec le TSSR` (nom exact, ne pas abréger) : `Forte` · `Moyenne` · `Faible`

Autres champs : `Entreprise` (titre) · `SIRET` · `Poste` · `Lien de l'offre` · `Localisation` ·
`Contact` · `E-mail` · `Téléphone` · `Date de découverte` · `Date de candidature` ·
`Date de relance` · `Prochaine action` · `Notes` · `Créé le`

**Interdits :** ne jamais modifier ni archiver une ligne existante ; ne jamais écrire
`Date de candidature`, `Date de relance` ni `Créé le` — ce sont ses champs.

**Les 2 lignes `IWIT Systems` et `We Admin IT` sont saisies à la main.** Elles n'ont pas de SIRET,
d'où le dédoublonnage à **double clé** : SIRET quand il existe, sinon nom normalisé (majuscules,
accents retirés, formes juridiques retirées, ponctuation retirée). Un contrôle sur le SIRET seul
les manquerait et ferait recandidater chez une entreprise déjà contactée.
`IWIT SYSTEMS` a pour SIRET `52510845200026` ; `We Admin IT` n'a aucune correspondance au registre.

## Secrets et quotas

Tout est dans `/opt/automation/workflows/marche-cache/.env` (`chmod 600`, jamais versionné),
10 variables renseignées. **Ne jamais les afficher en clair** : `set -a; . <fichier>; set +a`.

**Ces clés doivent être révoquées et régénérées** — elles ont transité par une conversation.
L'utilisateur le sait et compte le faire. Le workflow lit le `.env`, une rotation ne demande
aucune modification dans n8n. C'est la première ligne de la section correspondante du `TODO.md`.

**Chaîne de recherche avec bascule** (`SEARCH_ORDER`), ordonnée par quota gratuit mensuel :
`serper` (2 500) → `tavily` (1 000) → `firecrawl` (1 000) → `exa` (crédits) → `brave`
(**payant, 5 $ seulement**). Les cinq testés en HTTP 200, tous rendent le bon domaine en première
position. Bascule sur 401/402/403/429/5xx, délai dépassé, ou résultat vide — et pour **tout le
reste de l'exécution**, pas seulement l'entreprise en cours. Plafond `SEARCH_MAX_PER_RUN=120`.

**Groq, plan gratuit.** `llama-3.3-70b-versatile` : ~1 000 requêtes et **~100 K jetons par jour**.
`llama-3.1-8b-instant` : ~14 400 requêtes et ~500 K jetons. D'où le tri en trois étages du plan 09 :
filtre déterministe gratuit, puis le petit modèle en tri binaire, puis le gros modèle sur la
douzaine retenue seulement. Envoyer 200 annonces au gros modèle épuise le quota en une matinée.

n8n possède les credentials `Gmail IMAP`, `Groq API`, `Telegram bot`. Le mot de passe
d'application Gmail sert aussi à **déposer un brouillon** par IMAP — aucun OAuth nécessaire.

## Deux choses fragiles à surveiller

- **Le passage du nom d'entreprise à son domaine** est le seul maillon qu'aucune API publique
  française ne couvre, et le plus fragile du pipeline. Les moteurs renvoient volontiers un
  annuaire (`societe.com`, `pappers.fr`, `annuaire-entreprises`) plutôt que le site officiel :
  la liste d'exclusion est dans le plan 07, à durcir depuis les vrais ratés.
- **Une même alternance publiée par le CFA et par l'entreprise** apparaît sous deux raisons
  sociales différentes ; aucune clé ne les rapproche. La réponse n'est pas de dédoublonner mais
  de filtrer les organismes de formation et les agences d'intérim. Sur les 9 employeurs déjà en
  base, 2 sont des écoles (`ESICAD`, `ISCOD`) et 3 des agences (`ADECCO`, `Actual`, `JOB & VOUS`).

## Comment travailler avec lui

- Il veut des explications **en français, sans jargon**, comme à quelqu'un qui n'a jamais codé.
  Il demande le détail quand il en veut ; sinon, aller au fait.
- Il délègue le code à des **sous-agents Sonnet**, un par tâche, avec beaucoup de contexte et les
  skills nommées. Ne pas coder soi-même les tâches d'un plan.
- **Vérifier avant d'affirmer.** Il a relevé lui-même des affirmations non testées. Les agents de
  cette session ont trouvé trois erreurs dans mes propres plans — les rapports de sous-agents se
  contrôlent, ils ne se croient pas.
- Il corrige vite et franchement quand une direction ne lui convient pas. Prendre la correction,
  ne pas re-argumenter.
- Ne pas repitcher les sauvegardes : il a décliné le 30/09/2026 en connaissance du risque.
- Il documente tout sur ce serveur dans ce dépôt, qui est **une pièce de portfolio**. Les docs
  sont en anglais, le code et les commentaires en français. Rien ne doit y prétendre plus que ce
  qui tourne réellement.

## Pistes exploitables tout de suite, sans attendre l'outillage

`data/jobbot.db` (28 offres, profil `tssr-alternance`) contient déjà de vraies annonces trouvées
le 30/09/2026 sur Hellowork :

- Alternance BTS SIO — Technicien Informatique Support & Réseau (Toulouse)
- Alternance BTS SIO — Technicien Run / Support IT (Labège)
- Alternance BTS SIO — Assistant Informatique Bac+2 (Toulouse)

Le rappeler : l'outillage ne doit pas lui servir de raison d'attendre.
