# Maintenance Scripts

Host-level and container-level maintenance automation. This repository is the source of truth: scripts are edited here, then deployed to their target manually.

| Script | Target | Deployed as | Schedule |
|---|---|---|---|
| `proxmox-fstrim.sh` | Proxmox host | `/etc/cron.weekly/fstrim-lxc` | Weekly |
| `rclone-upload.sh` | LXC 101 (media-stack) | `/opt/mediaserver/upload_after_import.sh` | Every 15 minutes |
| `run-jobbot.sh` | Proxmox host | `crontab` (devkram user or root) | 4× daily (business hours) |

## proxmox-fstrim.sh

Iterates over running LXC containers and issues `pct fstrim` on each. Reclaims blocks inside the LVM-thin pool that guests have freed but never returned to the hypervisor — without it, the thin pool grows monotonically and eventually exhausts the SSD.

## rclone-upload.sh

Moves the local write cache (`/data/local`) to the encrypted Google Drive remote (`gcrypt:`), keeping the SSD from filling up while the MergerFS pool continues to serve both tiers transparently.

Operational safeguards built into the script:

- `flock` guard, so overlapping cron invocations cannot run concurrently
- `--min-age 15m`, so in-flight imports are never moved mid-write
- `--bwlimit 80M`, reserving bandwidth for Jellyfin playback
- `--tpslimit 4`, staying under Google Drive API rate limits
- Log rotation at 10 MB, keeping three archives

Credentials are read from `/root/.rclone-rc.conf` on the target host and are never stored in this repository. Set `DRY_RUN=1` to simulate a run without moving data.

## run-jobbot.sh

Runs the JobBot TSSR scraper.
Target: Proxmox Host.
Deployment: Add to user crontab (e.g. `crontab -e`) to run 4 times a day during business hours:
`0 8,12,16,20 * * 1-5 /home/devkram/homelab-infrastructure/scripts/run-jobbot.sh`

Operational safeguards built into the script:
- `flock` guard, so overlapping cron invocations cannot run concurrently
- Log rotation at 1 MB, keeping one archive
