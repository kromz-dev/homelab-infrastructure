# TODO

Open work, roughly in priority order. Closed items move to `CHANGELOG.md`.

## Resilience

- [ ] **No backup job covers LXC 101.** It is now the only guest on the node, and nothing schedules a vzdump. Any backup that does get taken also lands on the same SSD as the data it protects, so a disk failure loses both.

## Automation (LXC 102)

- [ ] **Back up `N8N_ENCRYPTION_KEY` off the host** (password manager). It lives only in `/opt/automation/.env`; losing it makes every stored credential unreadable.
- [ ] Keep `docker-stacks/automation/workflows/` in sync: re-export each workflow after editing it in the n8n UI (`n8n export:workflow`), so they survive a disk failure without a vzdump.
- [ ] `mail-triage` is active (2026-09-30). Run it for a week while still reading every mail while still reading every mail. Tighten the prompt from the misses.
- [ ] `mail-triage` costs ~690 Groq tokens per mail against the free plan's 200K tokens/day and 8K/min (~290 mails/day, ~11/min). Past that Groq answers 429 and the workflow fails open, notifying every mail. Check the daily volume after a week; if it is close, add a local pre-filter (e.g. `List-Unsubscribe` header) before the API call.
- [ ] Delete the leftover inactive `TEST erreur` workflow in the n8n UI (the CLI cannot delete).
- [ ] Redeploying `mail-triage` wipes the workflow's static data, so the day's pending digest entries and counters are lost. Deploy early in the day, or persist the digest outside n8n if that becomes a habit.
- [ ] The bulk heuristic (`List-Unsubscribe`) also catches legitimate automated mail (Pronote, other schools or platforms). Add each such sender's domain to `VIP_SENDERS` as it shows up in the digest.
- [ ] `mail-triage` sends sender, subject and the first 1500 characters of every mail to Groq, including bank/tax mail. Add a local rule to keep those senders off the API if that matters.
- [ ] Install Tailscale in LXC 102 and keep n8n private to the tailnet. Use Funnel on a single endpoint only if an external service must call a webhook.
- [ ] n8n idles at ~570 MB against a 2 GB limit (LXC has 3 GB). Watch it once scraping workflows run.
- [ ] n8n warns that internal task-runner mode is deprecated (`N8N_RUNNERS_MODE`). Move to an external runner when n8n actually removes it.

## Host and storage

- [ ] LXC 101 has a pending config change (`keyctl=1,fuse=1` under `[pve:pending]`) that the 2026-09-30 hardening entry reports as done. It only applies after a container restart.

- [ ] Reduce the rclone mount's `--timeout` from 1h — a read of an uncached file currently hangs for up to an hour when the link drops, instead of failing fast for Jellyfin.
- [ ] Remove the decommissioned scripts and stale compose files under `/opt/mediaserver` (LXC 101), and rotate the credentials they still reference.
- [ ] The rclone RC credential is duplicated between a service unit and the config file the upload script already reads. Keep the config file as the single source, so a rotation only has to touch one place.
- [ ] Add log rotation for `/var/log/rclone-gmedia.log` (56 MB, unrotated).
- [ ] Decide what to do with ~16 GB of torrents sitting on the cloud remote, left there before the pool was set to no-create.
- [ ] Investigate one stuck import (Criminal Minds S13E06) that never reached the library.

## Services

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
