# TODO

Open work, roughly in priority order. Closed items move to `CHANGELOG.md`.

## Resilience

- [ ] **No backup job covers any guest.** The node now runs three (LXC 101 media, 102 automation, 103 monitoring) and nothing schedules a vzdump. Any backup that does get taken also lands on the same SSD as the data it protects, so a disk failure loses both. Deliberately deferred on 2026-09-30, with the risk understood.
- [ ] LXC 103 sits at 192.168.1.39 while 101 and 102 are at .150 and .151. Decide on one addressing scheme, so a host is not guessed wrong in a script or a dashboard.

## Automation (LXC 102)

- [ ] **Back up `N8N_ENCRYPTION_KEY` off the host** (password manager). It lives only in `/opt/automation/.env`; losing it makes every stored credential unreadable.
- [ ] Keep `docker-stacks/automation/workflows/` in sync: re-export each workflow after editing it in the n8n UI (`n8n export:workflow`), so they survive a disk failure without a vzdump.
- [ ] `mail-triage` is active (2026-09-30). Run it for a week while still reading every mail while still reading every mail. Tighten the prompt from the misses.
- [ ] `mail-triage` costs ~690 Groq tokens per mail against the free plan's 200K tokens/day and 8K/min (~290 mails/day, ~11/min). Past that Groq answers 429 and the workflow fails open, notifying every mail. Check the daily volume after a week; if it is close, add a local pre-filter (e.g. `List-Unsubscribe` header) before the API call.
- [ ] **The `marche-cache` `workflow.json` in this repository is not byte-identical to the copy in LXC 102.** Diff them, decide which is right, and make the repository match the server (the sync rule above).
- [ ] A `.env.save` holding secrets remains in `workflows/mail-triage/` on the server: delete it. Two n8n API keys exist: keep one.
- [ ] The `jobbot-alert` workflow in n8n is still active although nothing calls it any more. Deactivate and delete it. JobBot's web interface (port 8766) also needs access control.
- [ ] LXC 102 reached 3048 MiB of 3072 at its peak. Watch it, and raise the limit if n8n and JobBot compete.
- [ ] Delete the leftover inactive `TEST erreur` workflow in the n8n UI (the CLI cannot delete).
- [ ] Redeploying `mail-triage` wipes the workflow's static data, so the day's pending digest entries and counters are lost. Deploy early in the day, or persist the digest outside n8n if that becomes a habit.
- [ ] The bulk heuristic (`List-Unsubscribe`) also catches legitimate automated mail (Pronote, other schools or platforms). Add each such sender's domain to `VIP_SENDERS` as it shows up in the digest.
- [ ] `mail-triage` sends sender, subject and the first 1500 characters of every mail to Groq, including bank/tax mail. Add a local rule to keep those senders off the API if that matters.
- [ ] Install Tailscale in LXC 102 and keep n8n private to the tailnet. Use Funnel on a single endpoint only if an external service must call a webhook.
- [ ] n8n idles at ~570 MB against a 2 GB limit (LXC has 3 GB). Watch it once scraping workflows run.
- [ ] n8n warns that internal task-runner mode is deprecated (`N8N_RUNNERS_MODE`). Move to an external runner when n8n actually removes it.

## Apprenticeship search (LXC 102)

- [ ] **Rotate the five search-provider keys and the Notion token** (confirmed still to do in the 2026-10-02 audit). They were pasted into a conversation during the 2026-09-30 setup. The workflow reads them from `.env`, so a rotation needs no change in n8n.
- [ ] `TELEGRAM_CHAT_ID` is still empty in `workflows/marche-cache/.env`. Copy it from `workflows/mail-triage/.env`.
- [ ] **A company whose registry lookup fails is dropped silently** in `marche-cache`. A sustained 429 after three retries would make valid companies disappear without a word. Count the items leaving `Extraire les dirigeants` with `registre != 'ok'` and surface it in the Telegram summary (task 5).
- [ ] Execute `docs/plans/2026-09-30-07-marche-cache-n8n.md`. The idempotence check is not optional: run the workflow twice in a row and confirm the Notion row count does not move.
- [ ] Create the francetravail.io account (open since 2026-09-17). Its "Offres d'emploi v2" API exposes a recruiter contact field that scraped job-board pages strip, and returns 150 offers per request instead of 60.
- [ ] Going from a company name to its domain is the one step no French public API covers, and the weakest link in the pipeline. Watch how often the search providers return a directory instead of the company site, and tighten the exclusion list from real misses.
- [ ] `jobbot-alert` (`docker-stacks/automation/workflows/`) is the earlier Python-pushes-to-webhook design, never configured and superseded by the n8n-owned pipeline. Delete it once the new workflow runs, together with the stale `workflow-jobbot-alert` entry in n8n.
- [x] Removed `scripts/run-jobbot.sh` and its root cron entry (2026-09-30). It ran four times a day as root — which is how the repository ended up root-owned — and had been failing since JobBot moved into the container. n8n now owns every trigger; verified no crontab, `cron.d` or systemd timer references JobBot.
- [ ] `stash@{0}` in the JobBot repository holds the abandoned TSSR work in progress, kept as reference. Drop it once the profile work has settled.

## Monitoring (LXC 103)

- [ ] Prometheus retention is set to 15 days on the same single SSD as the media library. Measure what that actually costs in gigabytes once the stack has run a full cycle, and shorten it if it competes with Jellyfin for space.
- [ ] **Nothing alerts.** Checked 2026-10-02: Uptime Kuma has 12 probes and 0 notification channels, Prometheus has 0 alert rules and no Alertmanager, Grafana has 0 alert rules. A failing service goes unnoticed until someone looks. Point Uptime Kuma at the Telegram bot the mail triage already uses, then add Prometheus rules.
- [ ] Pin the image tags: every service in this stack tracks `latest` except Uptime Kuma. (The Grafana admin password was confirmed changed on 2026-10-02.)
- [ ] **Grafana has no dashboard.** The documentation promised two; none was ever imported. Provision one for node metrics and one for cAdvisor.
- [ ] **LXC 103's disk is nearly full** (8 GB, about 97 % used on 2026-10-02) and Prometheus already ran out of space once, losing metrics. Prune unused images, cap the Docker logs, then enlarge the disk.
- [ ] `docker-compose.yml` declares Watchtower, but it was never pulled and does not run. Either remove the block or deploy it deliberately; as written, the next `docker compose up -d` would start it with write access to the Docker socket.
- [ ] A duplicate `node_exporter` systemd unit on the host restarts in a loop (tens of thousands of restarts) and fills the system journal. Disable the duplicate and keep the packaged exporter.
- [ ] LXC 103 has no `onboot`/`startup`: it does not come back after a host reboot.
- [ ] Monitoring endpoints are reachable from the whole LAN. Restrict each to the clients that need it.
- [ ] Dozzle mTLS is active, but how its certificates reach the agents is not described by any versioned compose file. Document it. Regenerate the certificates as a precaution.
- [ ] Decide whether Homepage and Grafana overlap enough that one of them should go. Two dashboards nobody opens is how this stack got decommissioned the first time.

## Host and storage

- [ ] **Host package repositories partly point at the previous Debian release**, so the host receives no security updates although it runs Debian 13. Impact: an unpatched hypervisor. Switch them to the current release and measure the gap before upgrading anything.
- [ ] **Host access is broader than the README says**: SSH settings, the Proxmox firewall (disabled), and a few services listening on the LAN need hardening. Put a key on the admin account and test it *before* closing any other way in.
- [ ] **The host's Tailscale key expires on 2026-10-10.** Remote access and the LAN route stop working that day unless it is renewed.
- [ ] Tighten the mount options of the `/opt/dev` bind mount (`nosuid,nodev`).
- [ ] A stray entry in the host's sudoers file looks like a typo. Review it, and review the Proxmox API users' roles.
- [ ] Python packages left on the host from the removed JobBot cron (`jobbot`, `numpy-config`): uninstall.
- [ ] The SSD logged 341 unclean power-offs. It is otherwise healthy; a UPS would address the counter.
- [ ] LXC 101 has a pending config change (`keyctl=1,fuse=1` under `[pve:pending]`) that the 2026-09-30 hardening entry reported as done. It only applies after a container restart; corrected in the 2026-10-02 changelog entry, still to be applied.
- [ ] **LXC 101 is privileged.** Its isolation from the hypervisor is weaker than an unprivileged container's. Convert it to unprivileged: this means rebuilding it or remapping its volume ownership, and keeping GPU passthrough for Jellyfin. Needs a plan, not a quick edit.
- [ ] Docker 20.10 and docker-compose 1.29 in LXC 101 are end-of-life. Upgrade.

- [ ] Reduce the rclone mount's `--timeout` from 1h — a read of an uncached file currently hangs for up to an hour when the link drops, instead of failing fast for Jellyfin.
- [ ] Remove the decommissioned scripts and stale compose files under `/opt/mediaserver` (LXC 101), and rotate the credentials they still reference.
- [ ] The rclone RC credential is duplicated between a service unit and the config file the upload script already reads. Keep the config file as the single source, so a rotation only has to touch one place.
- [ ] Add log rotation for `/var/log/rclone-gmedia.log` (56 MB, unrotated).
- [ ] Decide what to do with ~16 GB of torrents sitting on the cloud remote, left there before the pool was set to no-create.
- [ ] Investigate one stuck import (Criminal Minds S13E06) that never reached the library.

## Services

- [ ] **Authentication on some media-stack services needs strengthening** (details deliberately not written here while the fix is pending). Impact: anyone on the LAN can reach more than intended. Enable and enforce login on each, then regenerate the API keys of the services that were reachable.
- [ ] Several services publish their ports on all interfaces. Restrict each to the interface that needs it.
- [ ] Only one of eleven media containers has a health check, and recent failures went unnoticed for days (Seerr's sync since 2026-09-26, Bazarr's daily crash, one indexer returning nothing). Add health checks, and route their failures to the alerting above.
- [ ] Pin Sonarr and Radarr as well as Jellyfin: the whole stack tracks `latest`.
- [ ] Seerr's Jellyfin library sync returns 404 every 5 minutes. Reconfigure the library, or drop the service — nobody else on this LAN files requests.
- [ ] Recyclarr reports a successful sync but applies nothing to Sonarr (`qualities` missing from the profile). Fix the config, or drop it — TRaSH profiles are already in place.
- [ ] Align Radarr's authentication settings with Sonarr and Prowlarr.
- [ ] Pin Jellyfin's image tag. It is the one service where a major upgrade migrates the database irreversibly; the rest can stay on `latest` with a manual pull.
- [ ] Remove the unused NextPVR plugin from Jellyfin (fails to reach its backend on every startup).

## Hardware

- [ ] Confirm the specs of the two Intel NUC6CAYS (RAM, storage) before writing them in the README. One is the smart TV, the other is unused.

## Repository

- [ ] The three AI-skill symlinks use absolute paths, so they break for anyone who clones the repo. Make them relative.
- [ ] Decide whether `.github/skills/` earns its place — it is not a convention GitHub reads.
- [ ] Reword the `read_only: true` rule in `.cursorrules`. It is unrealistic for linuxserver.io images, whose s6-overlay writes inside the container at startup.
