# Contribuer au projet Collector.shop

## Branches
`main` est **protégée** : on n'y pousse jamais directement, tout passe par une pull request (PR).

| Préfixe | Usage | Exemple |
|---|---|---|
| `feat/` | Nouvelle fonctionnalité | `feat/catalog-submit-article` |
| `fix/` | Correction d'un défaut | `fix/fraud-threshold` |
| `docs/` | Documentation uniquement | `docs/remediation-plan` |
| `ci/` | Pipeline, Docker, Kubernetes, outillage | `ci/sonarqube-quality-gate` |
| `refactor/` | Amélioration du code sans changement de comportement | `refactor/catalog-repository` |
| `test/` | Ajout ou correction de tests uniquement | `test/price-change-acceptance` |

Nom de branche : en anglais, en minuscules, mots séparés par des tirets.

## Messages de commit et titres de PR — *Conventional Commits*
Format : `type(périmètre): description` — en anglais, à l'impératif, sans majuscule ni point final.

```
feat(catalog): add automatic listing control
fix(fraud): use absolute price variation
docs: add remediation plan
```

| Type | Effet sur la version (avant 1.0.0) | Usage |
|---|---|---|
| `feat` | 0.**x**.0 (version mineure) | Nouvelle fonctionnalité |
| `fix` | 0.0.**x** (correctif) | Correction |
| `docs`, `ci`, `refactor`, `test`, `perf`, `style`, `build` | aucune | Autres changements |
| `chore` | aucune | **Réservé aux outils automatiques** (Dependabot, release-please) |

Périmètres usuels : `catalog`, `notification`, `fraud`, `shared`, `frontend`, `infra`.

## Fusion
- **Squash and merge** uniquement : une PR = un seul commit sur `main`, dont le message est le **titre de la PR**.
- Le titre de la PR est vérifié automatiquement par la pipeline : un titre hors format bloque la fusion.
- La branche est supprimée automatiquement après la fusion.

## Versions
Gérées automatiquement par **release-please** à partir des titres de PR fusionnées :
1. à chaque fusion sur `main`, release-please met à jour une PR « chore(main): release x.y.z » contenant le `CHANGELOG.md` ;
2. fusionner cette PR crée le tag `vx.y.z` et la *release* GitHub.

## Cycle de travail
1. Créer ou choisir le ticket (GitHub Issues).
2. `git switch -c feat/<nom>` depuis `main` à jour.
3. Commits réguliers au format ci-dessus.
4. `git push -u origin feat/<nom>` puis ouvrir la PR (`Closes #<numéro du ticket>` dans la description).
5. Pipeline verte → *Squash and merge*.
