# 🚀 Enterprise-Grade Homelab Infrastructure

![Proxmox VE](https://img.shields.io/badge/Proxmox-8.x-E57000?style=for-the-badge&logo=proxmox)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker)
![Infrastructure as Code](https://img.shields.io/badge/IaC-GitOps-4CAF50?style=for-the-badge)

Welcome to my personal Infrastructure as Code (IaC) repository. This project manages a highly optimized, contanerized homelab environment running on Proxmox VE. 

The infrastructure is designed for low power consumption, maximum I/O efficiency using hybrid cloud storage (MergerFS + Rclone), and robust monitoring.

---

## 🖥️ Hardware Specifications

| Component | Specification | Notes |
|-----------|---------------|-------|
| **CPU** | Intel Core i3-8100 @ 3.60GHz | 4 Cores, 4 Threads. Features Intel UHD 630 (QSV) for hardware transcoding. |
| **RAM** | 16 GB DDR4 | Perfectly balanced; 4GB reserved for PVE, 12GB for workloads. |
| **Storage** | 250 GB SSD (LVM-Thin) | Western Digital SATA SSD. Augmented by Cloud Storage via Rclone. |
| **Network** | Realtek Gigabit | 1 Gb/s |

---

## 🏗️ Architecture & Software Stack

The system is compartmentalized into purpose-built Proxmox containers (LXC) and Virtual Machines (VMs) to ensure isolation and security.

### 1. 🍿 Media Stack (LXC 101)
*The core entertainment and automation engine, fully Dockerized.*
- **Media Engine:** Jellyfin (Intel QSV Hardware Accelerated), qBittorrent
- **Automation (Arrs):** Sonarr, Radarr, Prowlarr, Bazarr, Recyclarr
- **Storage:** Rclone (VFS Caching) + MergerFS (No-Create policy for perfect atomic hardlinks)
- **Dashboard & Utils:** Homepage, Seerr, Flaresolverr, Watchtower

### 2. 📈 Monitoring Stack (LXC 103)
*The observability platform.*
- **Core:** Prometheus, Grafana
- **Exporters:** cAdvisor, Blackbox, Speedtest, qBittorrent-exporter

### 3. 🏡 Domotics (VM 102)
- **Home Assistant OS (HAOS):** Dedicated VM for IoT and smart home automation.

### 4. 🛡️ Network & Security (Host)
- **Tailscale:** Host-level VPN for secure remote administration without port forwarding.

---

## 🗺️ System Diagram

```mermaid
flowchart TD
    Internet((Internet)) <--> Tailscale[Tailscale VPN]
    Tailscale <--> Proxmox[Proxmox VE Host]
    
    subgraph Proxmox [Proxmox VE (Hypervisor)]
        subgraph LXC101 [LXC 101: Media Stack]
            direction TB
            Docker1[Docker Compose] --> Jellyfin
            Docker1 --> Arrs[Sonarr/Radarr/Prowlarr]
            Docker1 --> qBit[qBittorrent]
            qBit --> MergerFS[(MergerFS Pool)]
            Arrs --> MergerFS
            Jellyfin --> MergerFS
            MergerFS --> Local[Local SSD Cache]
            MergerFS --> Rclone[Rclone Google Drive]
        end
        
        subgraph LXC103 [LXC 103: Monitoring]
            Prometheus --> Grafana
            Prometheus -.-> |Scrapes| LXC101
        end
        
        subgraph VM102 [VM 102: Domotics]
            HAOS[Home Assistant]
        end
    end
```

---

## 📂 Repository Structure

* `ansible/`: Playbooks for automated host and LXC provisioning.
* `docker-stacks/`: Docker Compose files segregated by stack (Media, Monitoring, etc.).
* `scripts/`: Bash automation scripts (Cron jobs, fstrim, cloud uploads).
* `docs/`: Network topologies and operational documentation.

## 🔐 Security & Secrets
All secrets (API keys, passwords, Tailscale auth keys) are explicitly excluded via `.gitignore`. To deploy this stack, copy the provided `.env.example` files to `.env` and populate them with your own credentials.
