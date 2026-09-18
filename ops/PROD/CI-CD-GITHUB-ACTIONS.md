# CI/CD GitHub Actions → EC2 (ImmoBudget)

À chaque push sur `main`, GitHub Actions valide la page puis déclenche le script
de déploiement [`update-last-version.sh`](update-last-version.sh) sur l'EC2 **via
AWS SSM** (aucune clé SSH, aucune clé AWS longue durée).

Workflow : [`.github/workflows/ci-cd.yml`](../../.github/workflows/ci-cd.yml)

C'est le **même pattern que le projet tikka**, mais simplifié : ImmoBudget est
une page 100% statique (aucun build, aucun backend, aucune base). Il n'y a donc
**ni job backend/frontend, ni transport S3 du build, ni swap, ni service
systemd** — l'EC2 récupère simplement la dernière version via `git reset --hard`
et nginx sert `index.html`.

## 1. Architecture

```
push sur main (ou pull request)
   │
   ├─ Job « validate » : vérifie index.html (présent, HTML, contient ImmoBudget)
   │
   └─ Job « deploy » (uniquement push sur main, si « validate » est vert)
        1. Assume un rôle IAM via OIDC (aws-actions/configure-aws-credentials)
        2. aws ssm send-command → update-last-version.sh sur l'EC2
           (git reset --hard origin/main + copie vers /var/www/immobudget + nginx)
        3. Attend la fin (polling get-command-invocation), affiche les logs,
           échoue si le script échoue
        4. Smoke test : curl https://immobudget.cloudsecops-services.com/
```

Points clés du workflow :

- `permissions: id-token: write` — indispensable pour l'OIDC vers AWS.
- `concurrency: deploy-immobudget-prod` — jamais deux déploiements en parallèle.
- `environment: production` — permet d'exiger une approbation manuelle (voir §4).
- Les pull requests exécutent seulement le job `validate`, jamais le deploy.

## 2. Authentification AWS par OIDC

**Rien à créer si tikka est déjà en place.** Le provider OIDC
`token.actions.githubusercontent.com` et le rôle de déploiement existent déjà,
et leur trust policy autorise **tout le dépôt de l'organisation** :

```json
"token.actions.githubusercontent.com:sub": [ "repo:devops-aws-ci/*" ]
```

→ `devops-aws-ci/ImmoBudget` est donc **déjà autorisé** à assumer le rôle.

Une seule vérification : l'inline policy du rôle autorise `ssm:SendCommand` /
`ssm:CancelCommand` sur l'ARN de l'instance. Comme ImmoBudget est déployé sur le
**même EC2 que tikka**, cet ARN est déjà couvert — aucune modification IAM n'est
nécessaire. (Si un jour ImmoBudget passe sur une autre instance, ajouter son ARN
à cette policy et mettre à jour `EC2_INSTANCE_ID`.)

Aucun accès S3 n'est requis (pas d'artefact de build à transporter).

### Prérequis côté EC2

- L'agent SSM tourne (déjà le cas — c'est le canal des sessions manuelles).
- L'instance profile inclut `AmazonSSMManagedInstanceCore` (déjà le cas).
- Le dépôt est cloné dans `/root/projects/immobudget` et `/var/www/immobudget`
  existe (voir le « premier déploiement » dans
  [`deploy-web-app-prod.md`](deploy-web-app-prod.md)).

## 3. Secrets GitHub

Repo → **Settings → Secrets and variables → Actions** :

| Secret                | Valeur                                                        |
| --------------------- | ------------------------------------------------------------ |
| `AWS_DEPLOY_ROLE_ARN` | ARN du rôle OIDC de déploiement (le **même** que tikka)      |
| `EC2_INSTANCE_ID`     | ID de l'instance EC2 (le **même** que tikka si serveur partagé) |

Aucune access key AWS n'est stockée : c'est tout l'intérêt de l'OIDC.

## 4. Approbation manuelle avant déploiement (optionnel)

Repo → **Settings → Environments → production** → **Required reviewers** : chaque
exécution du job `deploy` attendra alors une validation humaine dans l'onglet
Actions avant de toucher la prod.

## 5. Dépannage

| Symptôme | Cause probable / action |
| -------- | ----------------------- |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy qui ne matche pas le `sub`. Avec `environment: production`, le `sub` est `repo:devops-aws-ci/ImmoBudget:environment:production` — vérifier que la policy accepte `repo:devops-aws-ci/*`. |
| `Error: Credentials could not be loaded` | Secret `AWS_DEPLOY_ROLE_ARN` absent, ou `permissions: id-token: write` manquant. |
| `send-command` → `AccessDeniedException` | La policy du rôle ne couvre pas l'ARN de l'instance ou le document `AWS-RunShellScript`. |
| `InvalidInstanceId` | Instance éteinte, mauvais `EC2_INSTANCE_ID`, mauvaise région, ou agent SSM hors ligne. |
| Job « Attendre la fin » échoue en `TimedOut` alors que le script tourne | Vérifier l'historique SSM et l'URL publique ; le déploiement statique est normalement quasi instantané. |
| Script `Success` mais site cassé | `tail -20 /var/log/nginx/immobudget_error.log`, `sudo nginx -t`, `ls -l /var/www/immobudget/`. |
| Rollback | `cd /root/projects/immobudget && git reset --hard <sha> && bash ops/PROD/update-last-version.sh`. |
