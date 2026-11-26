# Expérience 3 — Communication asynchrone avec RabbitMQ

## Objectif
Valider le mécanisme de la fonctionnalité B (changement de prix) et sa **résilience** :
1. un événement `PriceChanged` publié **une seule fois** est reçu par **deux consommateurs indépendants** (`notification` et `fraud`), chacun dans sa propre file ;
2. si un consommateur est **arrêté**, l'événement est **conservé** dans sa file et traité **à son redémarrage** : aucune alerte de fraude n'est perdue ;
3. la règle anti-fraude (variation > 50 %) déclenche une alerte.

## Topologie testée
```
publisher ──► échange "collector.events" (topic) ──clé "catalog.price.changed"──┬──► file notification.price-changed ──► consumer-notification
                                                                               └──► file fraud.price-changed        ──► consumer-fraud
```
- Échange **durable**, files **durables de type quorum** (type recommandé par RabbitMQ 4), messages **persistants**.
- L'éditeur attend la **confirmation du broker** (*publisher confirms*) : un message confirmé est stocké.
- Les consommateurs n'acquittent (*ack*) qu'**après traitement** : livraison « au moins une fois ».

## Ce qui est déployé
| Fichier | Contenu |
|---|---|
| `00-namespace.yaml` | Namespace isolé `sandbox-mq` |
| `01-create-secrets.ps1` | Mot de passe RabbitMQ aléatoire dans un Secret Kubernetes (rien dans Git) |
| `10-rabbitmq.yaml` | RabbitMQ 4.1 (image officielle + console de gestion), volume persistant, non-root |
| `20-code.yaml` | Code de test Node.js (`amqplib`) : connexion avec reprise, éditeur, consommateur |
| `30-consumers.yaml` | Deux consommateurs : `consumer-notification`, `consumer-fraud` |
| `40-publish-job.yaml` | Scénario 1 : evt-001, article A-1001, 100 → 120 (+20 %) |
| `50-publish-job-resilience.yaml` | Scénario 2 : evt-002, article A-1002, 100 → 250 (+150 %) |
| `90-run-scenarios.ps1` | Exécute les deux scénarios et affiche OK / ECHEC pour chaque contrôle |

## Étapes (PowerShell, depuis la racine du dépôt)
```powershell
kubectl config use-context collector-poc
$exp = 'sandbox/03-rabbitmq'

kubectl apply -f $exp/00-namespace.yaml
powershell -ExecutionPolicy Bypass -File $exp/01-create-secrets.ps1

kubectl apply -f $exp/10-rabbitmq.yaml
kubectl rollout status -n sandbox-mq statefulset/rabbitmq --timeout=240s

kubectl apply -f $exp/20-code.yaml -f $exp/30-consumers.yaml
kubectl rollout status -n sandbox-mq deployment/consumer-notification --timeout=180s
kubectl rollout status -n sandbox-mq deployment/consumer-fraud --timeout=180s

powershell -ExecutionPolicy Bypass -File $exp/90-run-scenarios.ps1
```

## Résultat attendu
Tous les contrôles en `OK`, dont :
- `evt-002 conserve dans la file fraud.price-changed (messages en attente : 1)` pendant l'arrêt de `fraud` ;
- `fraud redemarre a recupere evt-002` puis `fraud a leve l'alerte (+150 % > 50 %)`.

## Console de gestion (facultatif, pour une capture)
```powershell
kubectl port-forward -n sandbox-mq svc/rabbitmq 15672:15672
```
Puis http://localhost:15672 (identifiant `collector`, mot de passe : `kubectl get secret sandbox-mq-secrets -n sandbox-mq -o jsonpath="{.data.password}"` à décoder en base64).

## Limites assumées (bac à sable)
- Un seul nœud RabbitMQ : une file quorum n'a donc qu'une réplique (en production : 3 nœuds).
- Pas de file de lettres mortes (*dead-letter queue*) : un message invalide est rejeté et perdu ; à ajouter dans l'application.
- Livraison « au moins une fois » : un même événement peut être reçu deux fois en cas de panne ; les services devront être idempotents (dédoublonnage par `eventId`).

## Nettoyage
```powershell
kubectl delete namespace sandbox-mq
```

## Résultats obtenus (24/11/2026)
**10 / 10 contrôles OK dès la première exécution.**

| Scénario | Contrôle | Résultat |
|---|---|---|
| 1 | Publication de evt-001 confirmée par le broker | OK |
| 1 | `notification` a reçu evt-001 | OK |
| 1 | `fraud` a reçu evt-001 | OK |
| 1 | Pas d'alerte pour +20 % | OK |
| 2 | Consommateur `fraud` arrêté | OK |
| 2 | Publication de evt-002 confirmée par le broker | OK |
| 2 | evt-002 conservé dans `fraud.price-changed` (1 message en attente) | OK |
| 2 | `notification` a reçu evt-002 sans attendre `fraud` | OK |
| 2 | `fraud` redémarré a récupéré evt-002 | OK |
| 2 | Alerte levée (+150 % > 50 %) puis file vidée | OK |

Extrait des journaux :
```
[notification] received evt-001 article=A-1001 100 -> 120 (20.0%)
[notification] received evt-002 article=A-1002 100 -> 250 (150.0%)
[fraud] received evt-002 article=A-1002 100 -> 250 (150.0%) ALERT variation above 50%
```
(Le journal de `fraud` ne montre que evt-002 : le pod a été recréé lors du scénario 2, ses journaux repartent de zéro.)

**Conclusion : technologie adoptée.** RabbitMQ découple le catalogue de ses consommateurs : chaque service a sa file, un service arrêté ne perd aucun événement et ne bloque pas les autres. L'outil anti-fraude (interne ou acheté, non décidé par la direction) pourra se brancher sur sa propre file sans modifier le catalogue.

**Ajustement après exécution :** ajout de `-c consumer` aux commandes `kubectl logs` du script pour supprimer le message informatif « Defaulted container » (dû au conteneur d'initialisation).
