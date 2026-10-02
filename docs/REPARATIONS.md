# Repair worklist

Prioritised, actionable follow-up from the 2026-10-02 audit. `TODO.md` holds the full gap list;
this file is the order to work in and the traps to avoid.

The detailed assessment, including severity reasoning, is deliberately **not** in this repository:
it describes weaknesses on a machine that is not fully hardened yet.

---

## Done on 2026-10-02

| What | Result |
|---|---|
| Package repositories still pointed at Debian 12 while the host ran Debian 13 | Fixed. The host had silently received **no security update at all**; the backlog was 252 packages |
| Full upgrade installed, reboot done | PVE 9.1.1 → 9.2.21, OpenSSL 3.5.4 → 3.5.7, libc6 → deb13u4. Kernel 6.17.2 → **7.0.14**. All 21 containers back, GPU passthrough intact, 5/5 Prometheus targets up, no failed unit |
| `node_exporter.service` restart loop (47 781 restarts, port already taken by the Debian package) | Duplicate unit disabled; the Debian package still serves the metrics. Journals 1.3 GB → 152 MB, `SystemMaxUse=500M` set |
| LXC 103 had neither `onboot` nor `startup` | Set. Verified: it came back by itself after the reboot |
| `rclone-gmedia.log` growing without bound (56 MB) | `logrotate` rule added (weekly, 3 archives, `copytruncate`) |
| Secret files readable by any local user | All tightened to `600`. A stale `.env.save` holding superseded credentials moved out of the working directory (kept, not deleted) |
| Leftover pip packages from the removed host cron | 11 packages removed from the hypervisor |
| Documentation claiming more than what runs | Corrected — see the 2026-10-02 `CHANGELOG.md` entries |

---

## 1. Time-bound — do this first

- [ ] **The host's Tailscale key expires 2026-10-10.** After that, remote access and the LAN route
      stop. Renewing is interactive, so nothing can do it for you.

## 2. Alerting — unlocks everything below it

Nothing on this node tells anyone when something breaks. Uptime Kuma has 12 probes and **0
notification channels**; Prometheus has 0 alert rules and no Alertmanager; Grafana has 0 alert
rules and 0 dashboards.

The cost is already measurable: Seerr has been failing to reach Jellyfin since **2026-09-26**,
Bazarr crashes nightly, one indexer stopped returning results, and Dozzle's remote log viewing has
never worked. None of it was reported.

- [ ] **Point Uptime Kuma at the Telegram bot the mail triage already uses.** Roughly 15 minutes,
      and it changes what this stack is for. Do this before anything else on the list.
- [ ] Import a node dashboard and a container dashboard into Grafana, or drop the claim entirely.
- [ ] Add Prometheus alert rules for the two conditions that have already bitten: container
      filesystem above 85 %, and a scrape target down for more than 5 minutes.

## 3. Service hardening — deferred by the owner on 2026-10-02

Reviewed and consciously postponed, not overlooked. All of these are LAN-only.

- [ ] **qBittorrent**: set a Web UI password, clear the authentication subnet whitelist, and stop
      bypassing authentication for local addresses.
- [ ] **Bazarr**: enable authentication (`auth.type` is unset), then rotate its API key — and
      Sonarr's and Radarr's, which its configuration holds.
- [ ] Restrict the published ports of the observability helpers (cAdvisor, node exporter,
      Prometheus, Homepage) so they are not reachable from the whole LAN.
- [ ] **JobBot (port 8766)** has no authentication and allows configuration changes. Either put it
      behind authentication or stop publishing its port.
- [ ] Remove the orphaned n8n workflow `workflow-jobbot-alert` and its unauthenticated webhook,
      plus the leftovers `TEST erreur` and `My workflow`. The CLI cannot delete workflows; use the
      UI.

## 4. Host access — order matters, see the warning

- [ ] **Finish SSH hardening.** A key for `devkram` is now authorised and works locally. Remaining:
      `PermitRootLogin no` and `PasswordAuthentication no`.

      > **Do it in this order or you lock yourself out.** 1. Generate a key on your workstation and
      > add its public half to `authorized_keys`. 2. Confirm `ssh devkram@192.168.1.250` works from
      > the workstation with no password. 3. Keep that session open. 4. Edit `sshd_config`, run
      > `sshd -t`, then `systemctl reload ssh`. 5. Open a **second** connection to confirm before
      > closing the first. Also confirm `devkram` has `sudo` — it replaces root.

- [ ] The Proxmox firewall is disabled. **Write and review the rules before enabling it**, at both
      datacenter and node level; enabling it empty cuts your own access.
- [ ] Review the Proxmox users and tokens: one account holds Administrator on `/`, root has no
      second factor, and `/etc/sudoers` contains a line that looks like a typo (`evops`).
- [ ] `rpcbind` (111) and `spiceproxy` (3128) listen on the LAN. Neither is needed here.

## 5. Capacity and durability

- [ ] **LXC 103 is at 91 %** (692 MB free on 8 GB) after cleanup. Its 6 Docker images alone take
      5.4 GB, so the disk has to grow — pick a size. Prometheus has already hit
      `no space left on device` once, losing two hours of metrics.
- [ ] Set `max-size` and `max-file` on the Docker log driver (compose or `daemon.json`), otherwise
      the Uptime Kuma log grows back past 140 MB.
- [ ] **341 unclean shutdowns** are recorded on the SSD. It is healthy otherwise — zero reallocated
      sectors — but that counter is what a UPS answers.
- [ ] LXC 102 peaked at 3048 MiB of its 3072 MiB limit.
- [ ] Docker 20.10 and docker-compose 1.29 in LXC 101 are end-of-life.

## 6. Change safety

- [ ] **Pin the image tags that matter.** Everything tracks `latest` except Uptime Kuma. Jellyfin
      is the dangerous one: a major upgrade migrates its database irreversibly. Pin Jellyfin,
      Sonarr and Radarr, and copy `config/jellyfin` before any deliberate upgrade.
- [ ] **No rollback path exists for a host upgrade.** Only 2.29 GB is free in the volume group, too
      little for a meaningful snapshot of the 68 GB root. The 2026-10-02 upgrade was done without
      one. Worth knowing before the next one.
- [ ] Add `nosuid,nodev` to the `mp0` bind mount of LXC 102. It needs a container restart, so fold
      it into the next planned reboot rather than scheduling an outage for it.
- [ ] Rotate the Dozzle certificates: they were exposed during the audit.
- [ ] Verify the three superseded credentials in the archived `.env.save` have really been revoked.
- [ ] Rotate the five search-provider keys and the Notion token used by the apprenticeship
      pipeline — they passed through a conversation.

## 7. Known broken, no deadline

- [ ] **Dozzle's remote log viewing has never worked.** Master and agents each hold an
      independently self-signed certificate, so the master's own handshake is rejected. Either
      provision one shared trust anchor — the `.dozzle_secrets` files were created for this and no
      compose file uses them — or drop the remote agents and keep Dozzle local to LXC 103.
- [ ] Seerr cannot reach Jellyfin (since 2026-09-26, retrying every 5 minutes), Bazarr has a task
      failing nightly at 04:00, and one indexer returns no results. All three need the UI.
- [ ] Only 1 of 11 containers in LXC 101 declares a healthcheck. The other ten can die unnoticed.
- [ ] **Objects in `.git/` keep ending up owned by `root`** (44 of them on 2026-10-02), which makes
      the next `git commit` fail with `insufficient permission for adding an object`. Something runs
      git under `sudo` — find it. Meanwhile the fix is
      `sudo chown -R devkram:devkram .git`.
- [ ] The `marche-cache` `workflow.json` differs between this repository and LXC 102. Decide which
      is authoritative and re-export.
- [ ] Watchtower is declared in the monitoring compose but has never been deployed. Deploy it
      deliberately or remove the declaration — but note it auto-updates `latest` images, which is
      exactly the risk item 6 warns about.

## 8. The larger project

- [ ] **Make LXC 101 unprivileged.** It is the only privileged container, which breaks the least
      privilege principle this repository states. Not a flag flip: it means rebuilding the
      container or remapping every volume's ownership, and Jellyfin needs the GPU to keep working.
      Plan it, do not improvise it.
- [ ] Backups: none are configured. **Recorded as fact, by the owner's decision — not a
      recommendation.**

---

## Paused work

The apprenticeship-search pipeline (`docs/plans/2026-09-30-07-marche-cache-n8n.md`) has tasks 1–4
done and verified; task 5 was interrupted. Task 5 is the one that writes to Notion and prepares the
application drafts. `docs/REPRISE.md` is the entry point for picking it up.
