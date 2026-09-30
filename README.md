<div align="center">
  <img src="https://img.shields.io/badge/Proxmox%20VE-E57000?style=flat-square&logo=proxmox&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Ansible-EE0000?style=flat-square&logo=ansible&logoColor=white" />
  <img src="https://img.shields.io/badge/Ubuntu-E95420?style=flat-square&logo=ubuntu&logoColor=white" />

  <h1>Homelab Infrastructure</h1>
  <p>Infrastructure as Code (IaC) repository for a hyperconverged homelab environment.</p>
</div>

---

## Overview

This repository manages the configuration, deployment, and automation of a single-node Proxmox VE environment. The infrastructure follows GitOps principles, ensuring all changes to the system state are version-controlled, reproducible, and deployed via code.

## Hardware Specifications

| Component | Specification | Description |
|---|---|---|
| **Hypervisor** | Proxmox VE 8.x | Bare-metal virtualization |
| **Compute** | Intel Core i3-8100 | 4 Cores @ 3.60GHz, QSV Passthrough enabled |
| **Memory** | 16 GB DDR4 | ECC unbuffered |
| **Storage** | 250 GB SATA SSD | LVM-Thin provisioned |
| **Network** | 1 Gbps Ethernet | Tailscale overlay network |

## Architecture Topology

The environment is strictly segregated into purpose-built containers (LXC) and virtual machines to ensure security boundaries and resource isolation.

```mermaid
flowchart LR
    subgraph Host [Proxmox VE Host]
        subgraph LXC101 [LXC 101 - Media Stack]
            direction LR
            Docker1[Docker Engine]
            Jellyfin[Jellyfin]
            Arrs[Sonarr/Radarr]
            Docker1 --- Jellyfin & Arrs
        end
    end

    subgraph Storage [Storage Backend]
        Local[Local SSD]
        Cloud[Cloud / Rclone]
        Pool{MergerFS}
        
        Local --> Pool
        Cloud --> Pool
    end

    Pool -->|Bind Mount| LXC101
```

## Directory Structure

- `ai-skills/` - Custom behavioral instructions for AI agents operating in this workspace.
- `ansible/` - Playbooks for host maintenance and service deployment.
- `docker-stacks/` - Compose definitions for containerized services.
- `docs/` - System architecture and incident response documentation.

## Core Design Principles

1. **Infrastructure as Code (IaC):** Server modifications are performed via configuration files, not manual command-line execution.
2. **Immutability & Least Privilege:** Containers utilize read-only mounts where possible. The `root` account is disabled for remote access, relying exclusively on an unprivileged `sudoer` account with SSH keys.
3. **Storage Efficiency:** Media management utilizes a hybrid local/cloud approach via MergerFS and Rclone. Local storage handles write-intensive operations, while cold data is asynchronously offloaded to cloud storage.
