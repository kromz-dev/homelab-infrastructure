# Observability & Monitoring Stack 👁️

> Ultimate Homelab Command Center with Performance Metrics, Alerting, Log Aggregation, and an interactive Dashboard.

## 🚀 Quick Start

1. Clone the repository and navigate to this folder.
2. Ensure you have copied `homepage/services.example.yaml` to `homepage/services.yaml` and filled in your API keys.
3. Generate `.dozzle_secrets` in your other stacks for secure log forwarding.
4. Run the stack:
   ```bash
   docker compose up -d
   ```

## 🏗️ Architecture

```mermaid
flowchart TD
    subgraph LXC_103 [LXC 103: Monitoring]
        H[Homepage :3002]
        K[Uptime Kuma :3001]
        G[Grafana :3000]
        P[Prometheus :9090]
        D[Dozzle Master :8888]
        W[Watchtower]
    end

    subgraph LXC_101 [LXC 101: Media]
        DA1[Dozzle Agent :7007]
        CA1[cAdvisor :9080]
        M[Media Apps]
    end

    subgraph LXC_102 [LXC 102: Automation]
        DA2[Dozzle Agent :7007]
        CA2[cAdvisor :9080]
        A[n8n & Bots]
    end

    Host[Proxmox Host :9100\nNode Exporter]

    %% Connections
    P -->|Scrapes| Host
    P -->|Scrapes| CA1
    P -->|Scrapes| CA2
    G -->|Reads| P
    D -->|mTLS| DA1
    D -->|mTLS| DA2
    H -->|API Calls| M
    H -->|API Calls| K
```

## ✨ Features

- **Grafana & Prometheus**: Real-time performance metrics (Hardware & Containers).
  - *Dashboard 1860*: Proxmox Node metrics.
  - *Dashboard 14282*: Docker cAdvisor metrics.
- **Uptime Kuma**: Active blackbox monitoring (Ping/HTTP) with notification routing.
- **Dozzle Multi-Node**: Real-time centralized log viewing across all LXCs via mTLS.
- **Homepage**: 3D glass-morphism command center linking all services.
- **Watchtower**: Silent auto-updating for the monitoring stack at 4:00 AM daily.

## ⚙️ Configuration

### Secret Management
⚠️ **Zero Secrets in Git**: 
- All `.env` and `.dozzle_secrets` files are strictly ignored.
- Homepage configuration (`services.yaml`) is git-ignored. Use `services.example.yaml` as your template.

### Adding a new Dozzle Agent
To link a new node to the Dozzle Master, create a `.dozzle_secrets` file in the target node's stack containing `DOZZLE_CERT_PEM` and `DOZZLE_KEY_PEM` to enforce mTLS.

## 📚 Documentation

- [Prometheus Configuration](prometheus.yml)
- [Homepage Templates](homepage/services.example.yaml)
- [Grafana Provisioning](docker-compose.yml)

## 📄 License
MIT
