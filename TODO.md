# TODO

Open work, roughly in priority order. Closed items move to `CHANGELOG.md`.

## Resilience

- [ ] **No backup job covers LXC 101.** It is now the only guest on the node, and nothing schedules a vzdump. Any backup that does get taken also lands on the same SSD as the data it protects, so a disk failure loses both.

## Automation (LXC 102)

- [ ] **Back up `N8N_ENCRYPTION_KEY` off the host** (password manager). It lives only in `/opt/automation/.env`; losing it makes every stored credential unreadable.
- [ ] Export the n8n workflows as JSON into this repo once the first ones exist, so they survive a disk failure without a vzdump.
- [ ] Install Tailscale in LXC 102 and keep n8n private to the tailnet. Use Funnel on a single endpoint only if an external service must call a webhook.
- [ ] n8n idles at ~570 MB against a 2 GB limit (LXC has 3 GB). Watch it once scraping workflows run.

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

## Repository

- [ ] The three AI-skill symlinks use absolute paths, so they break for anyone who clones the repo. Make them relative.
- [ ] Decide whether `.github/skills/` earns its place — it is not a convention GitHub reads.
- [ ] Revisit the README's "Infrastructure as Code / GitOps" framing now that the playbook is gone and scripts are deployed by hand.
- [ ] Reword the `read_only: true` rule in `.cursorrules`. It is unrealistic for linuxserver.io images, whose s6-overlay writes inside the container at startup.
