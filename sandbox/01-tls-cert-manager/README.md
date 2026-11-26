# Expérience 1 — HTTPS avec Ingress NGINX et cert-manager

## Objectif
Prouver qu'un service du cluster peut être exposé en **HTTPS** avec un certificat **émis et renouvelé automatiquement** par cert-manager, à partir d'une autorité de certification (CA) propre au projet.

## Ce qui est déployé
| Fichier | Contenu |
|---|---|
| `00-namespace.yaml` | Namespace isolé `sandbox-tls` |
| `10-ca-issuer.yaml` | Chaîne de confiance : émetteur auto-signé → certificat de la CA « Collector POC CA » → émetteur `collector-ca` |
| `20-demo-app.yaml` | Page web de test (Nginx non-root) + Service |
| `30-ingress.yaml` | Ingress `tls.collector.local` ; l'annotation cert-manager déclenche la création du certificat |
| `40-verify-job.yaml` | Job de vérification : appel HTTPS **avec vérification du certificat** par la CA du projet (sans option « insecure ») |

## Prérequis
- Cluster `collector-poc` démarré, addon `ingress` activé.
- Helm ≥ 3.

## Étapes (PowerShell, depuis la racine du dépôt)
```powershell
# 1. Se placer sur le bon cluster
kubectl config use-context collector-poc

# 2. Installer cert-manager (version figée pour la reproductibilité)
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager `
  --version v1.21.0 --namespace cert-manager --create-namespace `
  --set crds.enabled=true --wait

# 3. Déployer l'expérience
kubectl apply -f sandbox/01-tls-cert-manager/00-namespace.yaml
kubectl apply -f sandbox/01-tls-cert-manager/10-ca-issuer.yaml
kubectl wait --for=condition=Ready clusterissuer/collector-ca --timeout=90s
kubectl apply -f sandbox/01-tls-cert-manager/20-demo-app.yaml -f sandbox/01-tls-cert-manager/30-ingress.yaml
kubectl wait -n sandbox-tls --for=condition=Ready certificate/demo-tls --timeout=90s
kubectl rollout status -n sandbox-tls deployment/demo-web --timeout=120s

# 4. Vérifier
kubectl apply -f sandbox/01-tls-cert-manager/40-verify-job.yaml
kubectl wait -n sandbox-tls --for=condition=complete job/verify-https --timeout=90s
kubectl logs -n sandbox-tls job/verify-https
```

## Résultat attendu
- `certificate/demo-tls` à l'état `Ready=True`, émis par `collector-ca`.
- Les logs du Job affichent `HTTP 200` et `verification TLS : 0` (0 = certificat valide).

## Difficulté rencontrée (1re exécution)
Le Job a obtenu `HTTP 503` alors que la vérification TLS était déjà valide (`0`) : le Job s'est lancé avant que la page de test soit prête, l'Ingress n'avait donc aucun pod vers lequel router.
Correction : sonde de disponibilité (`readinessProbe`) sur la page de test, attente explicite du déploiement (`kubectl rollout status`) et nouvelles tentatives côté curl (`--retry`).

## Nettoyage
```powershell
kubectl delete namespace sandbox-tls
```
(cert-manager et l'émetteur `collector-ca` sont conservés : ils seront réutilisés par l'application.)

## Résultats obtenus (24/11/2026)
| Contrôle | Résultat |
|---|---|
| Installation cert-manager v1.21.0 (Helm, chart OCI) | `STATUS: deployed` |
| ClusterIssuer `collector-ca` | `Ready` |
| Certificat `demo-tls` (tls.collector.local) | `READY True`, émis automatiquement via l'annotation de l'Ingress |
| Appel HTTPS avec vérification par la CA du projet | `HTTP 200 \| verification TLS : 0 \| protocole : https` |

**Conclusion : technologie adoptée.** cert-manager + Ingress NGINX permettent d'exposer les services en HTTPS sans gestion manuelle de certificat. L'émetteur `collector-ca` sera réutilisé tel quel par l'application.

**Limite identifiée :** la CA est auto-signée, donc reconnue uniquement par les clients qui l'ont importée (navigateurs : avertissement de sécurité). En production, l'émetteur serait remplacé par Let's Encrypt (ACME) sans modifier les Ingress, seule l'annotation change.
