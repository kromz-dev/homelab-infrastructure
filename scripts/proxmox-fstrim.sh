#!/bin/bash
LOG=/var/log/fstrim-lxc.log
echo "=== $(date '+%F %T') debut fstrim-lxc ===" >> "$LOG"
for i in $(pct list | awk 'NR>1 {print $1}'); do
    # Check if container is running before attempting to trim
    if pct status $i | grep -q "running"; then
        echo "$(date '+%F %T') CT $i :" >> "$LOG"
        pct fstrim $i >> "$LOG" 2>&1 || echo "$(date '+%F %T') CT $i : ECHEC" >> "$LOG"
    fi
done
echo "=== $(date '+%F %T') fin fstrim-lxc ===" >> "$LOG"
