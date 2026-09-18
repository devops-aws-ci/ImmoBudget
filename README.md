# ImmoBudget

Simulateur personnel de trésorerie : effet d'une épargne dédiée au
remboursement d'un crédit immobilier. **Page web/mobile 100% statique**, aucun
backend, aucune donnée envoyée sur Internet — tout le calcul s'effectue
localement dans le navigateur.

> ⚠️ Simulation mathématique de trésorerie uniquement. Ce n'est **pas** un
> remboursement anticipé réel ni une modification du contrat bancaire : la
> banque prélève toujours la mensualité contractuelle.

## Utilisation locale

Ouvrir simplement `index.html` dans un navigateur — aucune installation.

## Fonctionnalités

- Mensualité réelle = `mensualité contractuelle − épargne / mensualités restantes`
- Complément mensuel pris dans l'épargne, épargne nécessaire, épargne restante
- Mode inverse « je veux payer X €/mois » + tableau d'objectifs (1 500 → 1 000 €)
- Durée du crédit : années déjà payées, années restantes, et **équivalent de
  l'épargne** en années/mois de mensualités
- Synthèse, mobile-first, thème clair/sombre, formatage € (fr-FR)

## Déploiement (EC2 / AWS — pattern tikka)

Déploiement calqué sur le projet **tikka**, simplifié pour un site statique :
push sur `main` → GitHub Actions → OIDC AWS → **SSM** → script sur l'EC2 → nginx.

- Workflow : [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml)
- Script EC2 : [`ops/PROD/update-last-version.sh`](ops/PROD/update-last-version.sh)
- Vhost nginx : [`ops/conf/immobudget.nginx.conf`](ops/conf/immobudget.nginx.conf)
- Guides : [`ops/PROD/deploy-web-app-prod.md`](ops/PROD/deploy-web-app-prod.md) ·
  [`ops/PROD/CI-CD-GITHUB-ACTIONS.md`](ops/PROD/CI-CD-GITHUB-ACTIONS.md)

URL publique cible : `https://immobudget.cloudsecops-services.com/`

### Mise en route (une seule fois)

1. **Secrets GitHub** (Settings → Secrets → Actions) : `AWS_DEPLOY_ROLE_ARN` et
   `EC2_INSTANCE_ID` (les mêmes que tikka si serveur partagé).
2. **EC2** (session SSM, en root) : cloner le dépôt dans
   `/root/projects/immobudget` et créer `/var/www/immobudget` (voir
   `deploy-web-app-prod.md`).
3. **DNS** : enregistrement `immobudget.cloudsecops-services.com` (Cloudflare)
   vers le même LB/EC2 que tikka.

Le rôle OIDC et l'autorisation SSM de tikka couvrent déjà ce dépôt et cette
instance — rien à recréer côté IAM. Ensuite, tout push sur `main` déploie
automatiquement.
