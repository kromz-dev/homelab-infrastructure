# TODO

Open work, roughly in priority order. Closed items move to `CHANGELOG.md`.

## Resilience

- [ ] **No backup job covers LXC 101.** It is now the only guest on the node, and nothing schedules a vzdump. Any backup that does get taken also lands on the same SSD as the data it protects, so a disk failure loses both.

## Host and storage

- [ ] Reduce the rclone mount's `--timeout` from 1h — a read of an uncached file currently hangs for up to an hour when the link drops, instead of failing fast for Jellyfin.
- [ ] Remove the decommissioned scripts and stale compose files under `/opt/mediaserver` (LXC 101), and rotate the credentials they still reference.
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
