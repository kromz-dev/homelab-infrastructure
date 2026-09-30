# Monitoring Stack

Observability for the homelab, deployed to LXC 103 (`monitoring`, 192.168.1.39, unprivileged,
2 cores / 2 GB / 8 GB).

## Services

| Service | Port | Role |
|---|---|---|
| Homepage | 3002 | Landing dashboard for every service on the node |
| Grafana | 3000 | Dashboards over the Prometheus data |
| Prometheus | 9090 | Metrics storage and scraping |
| Uptime Kuma | 3001 | Availability checks (ping / HTTP), with its own alerting |
| cAdvisor | 8080 | Per-container CPU, memory and I/O metrics |

## Deployment

```sh
docker compose up -d
```

Prometheus scrape targets are in [`prometheus.yml`](prometheus.yml).

## Why this stack exists twice

It was decommissioned on 2026-09-30 as unused, then reinstated the same day. The reasoning
changed with the node: at the time it watched a single media stack, which a glance at the shell
covered. The node now runs three containers and two long-lived automations — a mail triage and
an apprenticeship search — where a silent failure is not something anyone notices by looking.

cAdvisor was removed in that first pass because it cost real I/O on the single SSD (continuous
`/var/lib/docker` walks) with no consumer to justify it. It is back because Prometheus is back,
and because container memory is now worth watching: n8n idles around 570 MB against a 2 GB
limit.

## Known gaps

Prometheus retention is capped at 15 days (`--storage.tsdb.retention.time`), on the same single
SSD as the media library — what that costs in gigabytes still has to be measured over a full
cycle. Every image here tracks `latest`. See [`../../TODO.md`](../../TODO.md).
