# Collector.shop — POC

Plateforme de vente d'objets de collection entre particuliers (projet BLOC 3 — Superviser et assurer le développement des applications logicielles).

Fonctionnalité métier du POC : **mise en vente d'un article** (contrôle automatisé) et **changement de prix** (notification des acheteurs + détection de fraude).

## Structure du dépôt

| Dossier | Rôle |
|---|---|
| `services/` | Microservices Node.js / TypeScript / Express (`catalog`, `notification`, `fraud`), même structure en couches |
| `packages/shared/` | Code commun : vérification JWT, logs, métriques, types d'événements |
| `frontend/` | Mini front React + Vite (FR/EN, accessible) |
| `infra/docker/` | `docker-compose.yml` pour le développement local |
| `infra/k8s/` | Manifestes Kubernetes (Kustomize) pour Minikube |
| `infra/keycloak/` | Configuration du realm Keycloak (rôles, clients) |
| `tests/load/` | Scénarios de test de charge k6 |
| `tests/security/` | Configuration OWASP ZAP et tests d'accessibilité |
| `sandbox/` | Expérimentations technologiques isolées (une par dossier), préalables à l'intégration |
| `docs/` | Livrables écrits et décisions d'architecture (`adr/`) |
| `scripts/` | Scripts d'installation et de déploiement (PowerShell) |

## Structure d'un service

```
services/<nom>/
├── src/
│   ├── config/         # lecture des variables d'environnement
│   ├── routes/         # association URL → contrôleur
│   ├── controllers/    # lecture de la requête, envoi de la réponse HTTP
│   ├── services/       # règles métier
│   ├── repositories/   # accès à PostgreSQL
│   └── events/         # publication / consommation RabbitMQ
├── migrations/         # création et évolution des tables
└── tests/              # unit/ · integration/ · acceptance/
```

## Prérequis

- Node.js ≥ 22 (version cible : 24 LTS, voir `.nvmrc`)
- Docker Desktop
- Minikube, kubectl

## Démarrage

*À compléter au fil du projet.*

## Documentation

Voir [`docs/`](docs/README.md).
