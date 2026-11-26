# Politique de sécurité — Collector.shop

## Signaler une vulnérabilité
Ne pas ouvrir d'issue publique. Utiliser le signalement privé de GitHub (*Security → Report a vulnerability*) ; le Lead developer accuse réception sous 48 h ouvrées.

## Politique de seuil des contrôles automatiques
Bloquer toutes les alertes produit du bruit et des contournements : la pipeline **bloque** seulement ce qui présente un risque réel, le reste devient un **ticket daté avec un responsable**.

| Sévérité (CVSS) | Contexte | Décision de la pipeline | Délai de correction |
|---|---|---|---|
| Critique | Dépendance ou image utilisée en production | **Bloque** la fusion et la livraison | Immédiat |
| Élevée | Correctif disponible | **Bloque** la fusion et la livraison | Avant fusion |
| Élevée | Aucun correctif disponible | Ticket + exception documentée | 7 jours (réévaluation) |
| Moyenne | — | Ticket | 30 jours |
| Faible | — | Backlog | Selon priorité |
| Secret détecté (gitleaks) | — | **Bloque** toujours | Immédiat (voir ci-dessous) |

Outils : `npm audit` et Dependabot (dépendances), CodeQL et SonarQube Cloud (code), Trivy (images), gitleaks (secrets), OWASP ZAP (application déployée).

## Exceptions
Une exception est **écrite dans un ticket** avec : la vulnérabilité, la justification, le responsable, la mesure de contournement éventuelle et une **date d'expiration (30 jours maximum)**. Elle est validée par le Lead developer ; au-delà du mandat de l'équipe, le risque résiduel est accepté par la direction.

## Secrets
- Aucun secret dans le dépôt, les images ou les journaux : secrets Kubernetes générés par script, secrets GitHub Actions pour la pipeline.
- En cas d'exposition : **révoquer** puis **régénérer** le secret immédiatement, purger l'historique si nécessaire, analyser l'impact, ouvrir un ticket de retour d'expérience.
