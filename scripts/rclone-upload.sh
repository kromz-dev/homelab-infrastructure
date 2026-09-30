#!/bin/bash
# ==============================================================================
# Upload rclone (cache local -> Google Drive), lance par cron toutes les 15 min.
# Log : /var/log/rclone-upload.log   (DRY_RUN=1 pour simuler sans rien deplacer)
# ==============================================================================
set -u

LOCAL_DIR="/data/local/"
REMOTE_DIR="gcrypt:"
LOCKFILE="${LOCKFILE:-/tmp/rclone_upload.lock}"
LOG_FILE="/var/log/rclone-upload.log"
LOG_MAX_BYTES=$((10 * 1024 * 1024))
RC_CONF="/root/.rclone-rc.conf"
DRY_RUN="${DRY_RUN:-0}"

log() {
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

# Rotation simple : on garde le log courant + 3 archives
if [ -f "$LOG_FILE" ] && [ "$(stat -c %s "$LOG_FILE")" -gt "$LOG_MAX_BYTES" ]; then
    mv -f "$LOG_FILE.2" "$LOG_FILE.3" 2>/dev/null || true
    mv -f "$LOG_FILE.1" "$LOG_FILE.2" 2>/dev/null || true
    mv -f "$LOG_FILE" "$LOG_FILE.1"
fi

# Un seul upload a la fois
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    log "[INFO] Upload deja en cours, annulation."
    exit 0
fi

# shellcheck source=/dev/null
[ -r "$RC_CONF" ] && . "$RC_CONF"

log "[START] Debut de l'upload vers le Cloud (DRY_RUN=$DRY_RUN)"

# Toutes les options sont dans un tableau : aucune ligne ne peut etre perdue.
# --min-age 15m      : attendre 15 min apres creation (protege les imports en cours)
# --bwlimit 80M      : garde de la bande passante pour le streaming Jellyfin
# --drive-use-trash=false : pas de corbeille Google Drive
# --tpslimit 4       : evite les bans API Google
args=(
    move "$LOCAL_DIR" "$REMOTE_DIR"
    --exclude "torrents/**"
    --exclude ".keep"
    --delete-empty-src-dirs
    --min-age 15m
    --transfers 3
    --checkers 4
    --drive-chunk-size 128M
    --tpslimit 4
    --drive-use-trash=false
    --bwlimit 80M
    --stats 1m
    -v
)
[ "$DRY_RUN" = "1" ] && args+=(--dry-run)

/usr/bin/rclone "${args[@]}" >>"$LOG_FILE" 2>&1
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    log "[SUCCESS] Upload termine avec succes."
    if [ "$DRY_RUN" != "1" ]; then
        if /usr/bin/rclone rc vfs/refresh recursive=true _async=true \
            --rc-addr "${RC_ADDR:-127.0.0.1:5572}" \
            --rc-user "${RC_USER:-admin}" \
            --rc-pass "${RC_PASS:-}" >>"$LOG_FILE" 2>&1; then
            log "[INFO] vfs/refresh lance."
        else
            log "[WARN] vfs/refresh a echoue."
        fi
    fi
else
    log "[ERROR] Upload termine avec des erreurs (Code: $EXIT_CODE)."
fi

exit "$EXIT_CODE"
