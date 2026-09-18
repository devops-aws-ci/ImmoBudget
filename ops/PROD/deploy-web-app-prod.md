# Déploiement PROD de ImmoBudget — via session SSM sur l'EC2

Site **100% statique** (une seule page `index.html`, aucun build, aucun backend).
Servi par nginx sur le **même EC2 que tikka**, distingué par `server_name`.

## Déploiement manuel (session SSM en root)

```bash
sudo su -

cd /root/projects/immobudget
git fetch origin
git reset --hard origin/main

chmod +x /root/projects/immobudget/ops/PROD/update-last-version.sh
/root/projects/immobudget/ops/PROD/update-last-version.sh

echo "redeploy ok"
```

URL publique : https://immobudget.cloudsecops-services.com/

## Premier déploiement (one-shot, à faire une seule fois sur l'EC2)

```bash
sudo su -
mkdir -p /root/projects
# Cloner le dépôt (token GitHub avec accès lecture au dépôt privé) :
git clone https://<github_token>@github.com/devops-aws-ci/ImmoBudget.git /root/projects/immobudget
mkdir -p /var/www/immobudget

# Puis lancer le déploiement normal :
/root/projects/immobudget/ops/PROD/update-last-version.sh
```

Le script installe/active le vhost nginx `immobudget` et recharge nginx. Les
autres vhosts (tikka…) ne sont pas touchés.

## DNS / HTTPS

- Créer un enregistrement DNS `immobudget` sur `cloudsecops-services.com`
  (Cloudflare) pointant vers le même load balancer / EC2 que tikka.
- HTTPS assuré par Cloudflare (proxied) comme pour tikka ; nginx écoute en 80
  derrière le LB (voir la note sur les ports Cloudflare dans
  `ops/conf/immobudget.nginx.conf`).

## Diagnostic

```bash
sudo nginx -t                                    # conf nginx valide ?
tail -20 /var/log/nginx/immobudget_error.log     # erreurs nginx
ls -l /var/www/immobudget/                         # la page est-elle copiée ?
curl -I http://localhost -H "Host: immobudget.cloudsecops-services.com"
```

## Rollback

```bash
cd /root/projects/immobudget
git reset --hard <sha_précédent>
bash ops/PROD/update-last-version.sh
```
