# 🚀 Enterprise-Grade Homelab Infrastructure

<p align="center">
  <img src="https://img.shields.io/badge/Proxmox%20VE-E57000?style=for-the-badge&logo=proxmox&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white" />
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" />
</p>

Welcome to my personal Infrastructure as Code (IaC) repository. This repository documents and manages my hyperconverged Homelab environment running on **Proxmox VE**, utilizing strict DevOps principles, GitOps workflows, and TRaSH-Guides standards.

---

## 🏗️ Hardware Specifications

The infrastructure is hosted on a single-node hypervisor optimized for low power consumption and high efficiency (Intel QSV hardware transcoding).

| Component | Specification | Notes |
| :--- | :--- | :--- |
| **CPU** | Intel Core i3-8100 (4 Cores @ 3.60GHz) | Intel UHD 630 (QSV Passthrough enabled) |
| **Memory** | 16 GB DDR4 | 2GB Swap configured for Docker |
| **Storage** | 250 GB SATA SSD | LVM-Thin Provisioning (fstrim optimized) |
| **Network** | 1 Gbps Ethernet | Tailscale Zero-Trust VPN |

---

## 🕸️ Architecture Topology

The infrastructure is strictly segregated into dedicated LXC containers and Virtual Machines for security and resource management.

```mermaid
graph TD
    %% Define Styles
    classDef hypervisor fill:#e57000,stroke:#fff,stroke-width:2px,color:#fff,font-weight:bold;
    classDef lxc fill:#2496ed,stroke:#fff,stroke-width:2px,color:#fff;
    classDef vm fill:#4caf50,stroke:#fff,stroke-width:2px,color:#fff;
    classDef storage fill:#ffb300,stroke:#fff,stroke-width:2px,color:#222;
    classDef service fill:#333,stroke:#666,stroke-width:1px,color:#fff;

    %% Nodes
    PVE[Proxmox VE Host]:::hypervisor

    subgraph Containers [LXC Infrastructure]
        LXC101[LXC 101: Media Stack]:::lxc
        LXC103[LXC 103: Observability]:::lxc
    end

    subgraph VirtualMachines [VM Infrastructure]
        VM102[VM 102: Home Assistant OS]:::vm
    end

    subgraph Storage [Storage Backend]
        SSD[(Local SSD)]:::storage
        GDRIVE[(Google Drive / Rclone)]:::storage
        MERGERFS{MergerFS =NC}:::storage
    end

    %% Connections
    PVE --> Containers
    PVE --> VirtualMachines

    %% Media Stack Details
    LXC101 -->|Docker| JELLYFIN[Jellyfin QSV]:::service
    LXC101 -->|Docker| ARRS[Sonarr/Radarr]:::service
    LXC101 -->|Docker| QBIT[qBittorrent RAM Cache]:::service
    
    %% Storage Links
    SSD -.-> MERGERFS
    GDRIVE -.-> MERGERFS
    MERGERFS -->|Bind Mount| LXC101

    %% Monitoring Links
    LXC103 -->|Prometheus| PVE
    LXC103 -->|Grafana| PVE
```

---

## 📂 Repository Structure

```text
homelab-infrastructure/
├── 📁 ai-skills/            # Embedded AI Assistant Behaviors & Policies
├── 📁 ansible/              # IaC Playbooks for server maintenance and deployment
├── 📁 docker-stacks/        # Docker Compose files (Media, Monitoring, etc.)
│   └── 📁 media-stack/      # TRaSH-Guides compliant media environment
├── 📁 docs/                 # Detailed architectural documentation
└── 📄 CHANGELOG.md          # Immutable history of server modifications
```

---

## 🔒 Security & DevOps Philosophy

1. **Principle of Least Privilege**: The `root` account is disabled for direct SSH. Administration is performed via a dedicated `sudoer` account (`devkram`) using ED25519 SSH Keys.
2. **Immutability**: Containers rely on Read-Only mounts and strict PUID/PGID enforcement.
3. **Storage Efficiency**: The Media Stack utilizes an advanced `MergerFS` + `Rclone` hybrid architecture. Downloads hit the local SSD, are atomically hardlinked by Sonarr/Radarr, and automatically offloaded to the encrypted cloud overnight to preserve local storage.
4. **AI-Assisted Operations**: This repository contains global `.cursorrules` and embedded AI skills (`ai-skills/homelab-devops-engineer`) to ensure any AI agent interacting with this server adheres strictly to these infrastructure rules.

