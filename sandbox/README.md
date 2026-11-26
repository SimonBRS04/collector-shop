# Bac à sable — expérimentations technologiques

Chaque expérience teste **une** technologie clé, isolée dans son propre namespace du cluster `collector-poc`, avant son intégration dans l'application.
La synthèse (environnement, étapes, difficultés, résultats, décision) est rédigée dans [`docs/05-protocole-experimentation.md`](../docs/05-protocole-experimentation.md).

| # | Dossier | Technologie | Namespace | Statut |
|---|---|---|---|---|
| 1 | `01-tls-cert-manager/` | Ingress NGINX + cert-manager (HTTPS) | `sandbox-tls` | Validée |
| 2 | `02-keycloak/` | Keycloak sur PostgreSQL (OIDC, JWT, rôles) | `sandbox-auth` | Validée |
| 3 | `03-rabbitmq/` | RabbitMQ (1 événement → 2 consommateurs, résilience) | `sandbox-mq` | Validée |
| 4 | `04-observability-hpa/` | Prometheus + Grafana + HPA sous charge k6 | `sandbox-obs` + `monitoring` | Validée |

Convention : les fichiers YAML sont préfixés par un numéro (`00-`, `10-`, `20-`…) qui indique l'ordre d'application.
