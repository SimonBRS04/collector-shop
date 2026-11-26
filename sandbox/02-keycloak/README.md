# Expérience 2 — Authentification avec Keycloak (sur PostgreSQL)

## Objectif
Prouver que :
1. Keycloak fonctionne dans le cluster en mode production, **avec sa base PostgreSQL** ;
2. il délivre des jetons JWT portant les **rôles métier** (`buyer`, `seller`, `admin`) ;
3. une API vérifie elle-même ces jetons (signature, émetteur, audience) et applique les rôles :
   **401** sans jeton ou jeton falsifié, **403** avec un mauvais rôle, **200** avec le bon rôle.

C'est le mécanisme qu'utiliseront les trois services de l'application.

## Ce qui est déployé
| Fichier | Contenu |
|---|---|
| `00-namespace.yaml` | Namespace isolé `sandbox-auth` |
| `01-create-secrets.ps1` | Génère des mots de passe aléatoires dans un Secret Kubernetes (rien dans Git) |
| `10-postgres.yaml` | PostgreSQL 17 (StatefulSet, volume persistant 1 Gi, non-root) |
| `20-keycloak-realm.yaml` | Realm `collector-sandbox` : rôles, client de test, mapper d'audience `collector-api`, 2 utilisateurs |
| `30-keycloak.yaml` | Keycloak 26.7.2 (`start`, PostgreSQL, sondes de santé) + Ingress HTTPS `auth.collector.local` (certificat `collector-ca`) |
| `02-set-test-passwords.ps1` | Définit les mots de passe des utilisateurs de test depuis le Secret (outil `kcadm`) |
| `40-protected-api.yaml` | API de test Node.js : vérification JWT avec la bibliothèque `jose` (JWKS de Keycloak) + contrôle du rôle `seller` |
| `50-verify-job.yaml` | 7 scénarios automatiques (jetons, 200 / 401 / 403) |

Utilisateurs de test : `seller-test` (rôles `seller` + `buyer`), `buyer-test` (rôle `buyer`).

## Étapes (PowerShell, depuis la racine du dépôt)
```powershell
kubectl config use-context collector-poc
$exp = 'sandbox/02-keycloak'

# 1. Namespace + secrets
kubectl apply -f $exp/00-namespace.yaml
powershell -ExecutionPolicy Bypass -File $exp/01-create-secrets.ps1

# 2. PostgreSQL
kubectl apply -f $exp/10-postgres.yaml
kubectl rollout status -n sandbox-auth statefulset/postgres --timeout=180s

# 3. Keycloak (le premier démarrage peut prendre 2 à 4 minutes)
kubectl apply -f $exp/20-keycloak-realm.yaml -f $exp/30-keycloak.yaml
kubectl rollout status -n sandbox-auth deployment/keycloak --timeout=360s
powershell -ExecutionPolicy Bypass -File $exp/02-set-test-passwords.ps1

# 4. API protégée
kubectl apply -f $exp/40-protected-api.yaml
kubectl rollout status -n sandbox-auth deployment/protected-api --timeout=180s

# 5. Vérification
kubectl apply -f $exp/50-verify-job.yaml
kubectl wait -n sandbox-auth --for=condition=complete job/verify-auth --timeout=120s
kubectl logs -n sandbox-auth job/verify-auth
```

Pour relancer la vérification : `kubectl delete job verify-auth -n sandbox-auth` puis réappliquer `50-verify-job.yaml`.

## Résultat attendu
```
OK     jeton vendeur obtenu
OK     jeton acheteur obtenu
OK     ressource publique, sans jeton       -> 200
OK     ressource vendeur, sans jeton        -> 401
OK     ressource vendeur, jeton falsifie    -> 401
OK     ressource vendeur, jeton acheteur    -> 403
OK     ressource vendeur, jeton vendeur     -> 200
```

## Limites assumées (bac à sable)
- Le grant `password` (client `sandbox-tester`) sert uniquement au test automatisé ; l'application utilisera le flux *authorization code + PKCE* (keycloak-js).
- Une seule instance de Keycloak et de PostgreSQL (pas de haute disponibilité).
- Le mot de passe admin passe en argument de `kcadm` dans le conteneur : acceptable en bac à sable, à remplacer par un compte de service en production.

## Nettoyage
```powershell
kubectl delete namespace sandbox-auth
```

## Résultats obtenus (24/11/2026)
| Contrôle | Résultat |
|---|---|
| PostgreSQL 17 (StatefulSet, volume persistant) | Prêt (`pg_isready`) |
| Keycloak 26.7.2 en mode `start`, base PostgreSQL, import du realm | Déployé (sondes de santé OK), démarrage en moins de 6 min |
| Mots de passe des utilisateurs de test via `kcadm` depuis le Secret | Définis |
| API de test (vérification JWT `jose` + rôle) | Déployée |
| Scénarios de vérification | **7 / 7 OK** dès la première exécution |

Détail des scénarios : jetons vendeur et acheteur obtenus ; ressource publique sans jeton → 200 ; ressource vendeur sans jeton → 401 ; jeton falsifié → 401 ; jeton acheteur (mauvais rôle) → 403 ; jeton vendeur → 200.

**Conclusion : technologies adoptées (Keycloak + PostgreSQL).** L'authentification est déléguée à Keycloak ; chaque service vérifie localement le jeton (signature via JWKS, émetteur, audience) puis le rôle, sans appel à Keycloak à chaque requête. Le modèle de vérification de l'API de test sera repris dans `packages/shared`.

**Points d'attention pour l'intégration :** l'émetteur (`iss`) des jetons est l'URL publique `https://auth.collector.local/...` alors que les services récupèrent les clés en interne (`http://keycloak...:8080`) : les deux URL doivent être configurées séparément dans chaque service.
