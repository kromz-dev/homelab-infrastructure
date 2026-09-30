#!/bin/bash
# Description: Script pour lancer le scraper JobBot automatiquement.
# Target: Proxmox Host ou LXC (là où Python est installé)
# Schedule recommandé : Toutes les 4 heures en journée (ex: 0 8,12,16,20 * * *)

set -euo pipefail

# Emplacement du projet
JOBBOT_DIR="/home/devkram/dev/jobbot"
LOG_DIR="$JOBBOT_DIR/logs"
LOG_FILE="$LOG_DIR/jobbot-cron.log"
LOCK_FILE="/tmp/run-jobbot.lock"

# Empêcher les exécutions simultanées
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "Une autre instance est déjà en cours d'exécution." >&2; exit 1; }

mkdir -p "$LOG_DIR"

# Rotation des logs (1MB max, garder le .1)
if [ -f "$LOG_FILE" ]; then
    SIZE=$(stat -c %s "$LOG_FILE")
    if [ "$SIZE" -gt 1048576 ]; then
        mv "$LOG_FILE" "$LOG_FILE.1"
    fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Début de l'exécution de JobBot" >> "$LOG_FILE"

cd "$JOBBOT_DIR" || { echo "Erreur: Dossier $JOBBOT_DIR introuvable" >> "$LOG_FILE"; exit 1; }

# Lancement du scraping (JobBot installé globalement)
python3 -m jobbot scrape >> "$LOG_FILE" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fin de l'exécution" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"
