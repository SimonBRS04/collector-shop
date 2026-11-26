# ADR-0001 — Monorepo avec npm workspaces

- **Date** : 2026-11-05
- **Statut** : accepté

## Contexte
Le POC comporte trois microservices, un front-end, du code commun (JWT, logs, métriques) et l'infrastructure. L'équipe est petite (1 lead dev + 2 développeurs) et doit pouvoir ajouter rapidement de nouvelles fonctionnalités (enchères, streaming…).

## Décision
Un seul dépôt Git (monorepo) piloté par **npm workspaces**. Chaque service garde son propre `package.json` et son `Dockerfile` ; le code commun vit dans `packages/shared`.

## Alternatives écartées
- **Un dépôt par service** : multiplie les pipelines et la gestion des versions du code commun, disproportionné pour une équipe de 3.
- **Nx / Turborepo** : outillage puissant mais courbe d'apprentissage supplémentaire, inutile à cette échelle.

## Conséquences
- Un seul pipeline CI, une seule revue de code, cohérence garantie entre services.
- Ajouter un service = copier la structure standard d'un dossier `services/`.
- Vigilance : les services restent déployés et versionnés indépendamment (une image Docker par service).
