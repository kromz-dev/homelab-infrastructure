# Monitoring Stack

Cette stack contient l'infrastructure de supervision pour le homelab (LXC 103).

## Services
- **Homepage** (:3002) : Dashboard d'accueil "Obsidian Command Center".
- **Prometheus** (:9090) : Time-series database pour stocker les métriques.
- **Grafana** (:3000) : Visualisation des métriques Prometheus.
- **Uptime Kuma** (:3001) : Monitoring de la disponibilité des services (Ping/HTTP).
- **cAdvisor** (:8080) : Exportateur de métriques pour les conteneurs Docker.

## Déploiement
Se déploie dans le LXC 103 (monitoring).
\`\`\`bash
docker compose up -d
\`\`\`
