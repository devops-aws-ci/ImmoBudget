#! /bin/bash
## Script de redéploiement de ImmoBudget — site 100% statique (une page HTML,
## aucun build, aucun backend, aucune base de données).
## À lancer en root sur l'EC2 (via session SSM), ou déclenché par la CI/CD
## GitHub Actions via `aws ssm send-command` (voir CI-CD-GITHUB-ACTIONS.md).
## Idempotent.

# Tout échec réel (nginx -t, copie…) arrête le script et fait échouer le job de
# déploiement. Les checks purement informatifs sont suffixés `|| true`.
set -e

# Verrou anti-déploiements concurrents.
# SSM peut recevoir plusieurs `send-command` qui se chevauchent (re-run /
# annulation GitHub : GitHub cesse de surveiller mais la commande continue côté
# EC2). Deux `git reset --hard` simultanés corrompent l'arbre de travail. On
# sérialise donc via flock : si un déploiement est déjà en cours, on abandonne
# immédiatement avec un message clair.
exec 9>/var/lock/immobudget-deploy.lock
if ! flock -n 9; then
  echo "ERREUR : un déploiement ImmoBudget est déjà en cours (verrou /var/lock/immobudget-deploy.lock). Abandon."
  exit 1
fi

# SSM RunShellScript exécute en root sans shell interactif : pas de prompt apt.
export DEBIAN_FRONTEND=noninteractive

REPO_DIR=/root/projects/immobudget
WEB_ROOT=/var/www/immobudget
SERVER_NAME=immobudget.cloudsecops-services.com

######## Premier déploiement uniquement (one-shot manuel) :
# sudo su -
# mkdir -p /root/projects
# git clone https://{github_token}@github.com/devops-aws-ci/ImmoBudget.git /root/projects/immobudget
# sudo mkdir -p /var/www/immobudget

######## Récupère la dernière version du dépôt
cd "$REPO_DIR"
git fetch origin
git reset --hard origin/main

######## Déploiement du site statique (copie de la page servie par nginx)
echo "start deploy static site"
sudo mkdir -p "$WEB_ROOT"
sudo cp "$REPO_DIR/index.html" "$WEB_ROOT/"
ls -l "$WEB_ROOT/"

######## Mise à jour de la conf nginx (vhost dédié, cohabite avec les autres)
sudo cp "$REPO_DIR/ops/conf/immobudget.nginx.conf" /etc/nginx/sites-available/immobudget
sudo rm -f /etc/nginx/sites-enabled/immobudget
sudo ln -s /etc/nginx/sites-available/immobudget /etc/nginx/sites-enabled/immobudget
sudo nginx -t
sudo systemctl reload nginx
echo "end deploy static site"

######## CHECK (informatif — ne fait pas échouer le déploiement)
# 1. La page répond (200 + text/html attendu)
curl -I "http://localhost" -H "Host: $SERVER_NAME" || true
# 2. Le HTML servi est bien la page ImmoBudget
curl -s "http://localhost" -H "Host: $SERVER_NAME" | grep -o 'ImmoBudget' | head -1 || true
# 3. nginx tourne
systemctl is-active nginx || true

echo "Déploiement terminé avec succès."

######## Diagnostic si problème :
# sudo nginx -t                                   # conf nginx valide ?
# tail -20 /var/log/nginx/immobudget_error.log    # erreurs nginx
# ls -l /var/www/immobudget/                       # la page est-elle bien copiée ?
# curl -I http://localhost -H "Host: immobudget.cloudsecops-services.com"

######## Rollback :
# cd /root/projects/immobudget && git reset --hard <sha_précédent> \
#   && bash ops/PROD/update-last-version.sh
