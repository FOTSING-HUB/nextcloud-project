# Nextcloud - Cloud Personnel

Déploiement production-ready d'un cloud personnel Nextcloud avec Docker, CI/CD et backup automatique S3.

## Architecture

| Composant | Rôle | Image |
|---|---|---|
| Nginx + ModSec | Reverse proxy, WAF, Load Balancer | owasp/modsecurity-crs:nginx-alpine |
| Nextcloud x2 | Application (instances redondantes) | Custom (ECR) |
| PostgreSQL 15 | Base de données | postgres:15-alpine |
| Redis 7 | Cache sessions et verrous | redis:7-alpine |
| Prometheus | Collecte métriques | prom/prometheus |
| Grafana | Dashboards monitoring | grafana/grafana |
| Loki + Promtail | Logs centralisés | grafana/loki + grafana/promtail |

## Prérequis

- Docker >= 24.0
- Docker Compose >= 2.20
- Git
- Compte AWS (ECR + S3)

## Installation rapide

```bash
# 1. Cloner le projet
git clone <votre-repo> nextcloud-project
cd nextcloud-project

# 2. Configurer les variables d'environnement
cp .env.example .env
nano .env    # Remplir toutes les valeurs CHANGE_ME

# 3. Configurer rclone pour S3
cp backup/rclone.conf.example backup/rclone.conf

# 4. Lancer les services
docker compose up -d

# 5. Vérifier que tout tourne
docker compose ps
docker compose logs -f
```

## Accès aux services

| Service | URL | Identifiants |
|---|---|---|
| Nextcloud | http://localhost | Définis dans .env |
| Grafana | http://localhost:3000 | admin / (NEXTCLOUD_ADMIN_PASSWORD) |

## Commandes utiles

```bash
# Voir l'état de tous les services
docker compose ps

# Logs d'un service spécifique
docker compose logs -f nextcloud_app1

# Redémarrer un service
docker compose restart nginx

# Lancer une sauvegarde manuelle
docker compose run --rm nextcloud_cron /backup/backup.sh

# Mise à jour de l'image Nextcloud
docker compose pull && docker compose up -d

# Sauvegarde de la base de données manuellement
docker compose exec postgres pg_dump -U nextcloud nextcloud > backup_$(date +%Y%m%d).sql
```

## Structure des fichiers

```
nextcloud-project/
├── nginx/
│   ├── nginx.conf           # Reverse proxy + Load Balancer
│   └── modsecurity.conf     # Configuration WAF
├── nextcloud/
│   ├── Dockerfile           # Image personnalisée
│   └── healthcheck.sh       # Script de santé
├── monitoring/
│   ├── prometheus.yml       # Scrape config
│   ├── promtail.yml         # Collecte logs
│   └── grafana/             # Dashboards
├── backup/
│   ├── backup.sh            # Script de sauvegarde
│   └── rclone.conf.example  # Template config S3
├── .github/workflows/
│   └── ci-cd.yml            # Pipeline CI/CD
├── docker-compose.yml       # Orchestration complète
├── .env.example             # Template des variables
└── README.md
```

## CI/CD Pipeline

Le pipeline GitHub Actions effectue automatiquement :

1. **Build** - Construction de l'image Docker personnalisée
2. **Test** - Validation du conteneur et du docker-compose
3. **Push ECR** - Publication sur Amazon ECR
4. **Deploy** - Déploiement rolling sans interruption

Secrets GitHub à configurer :
- `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY`
- `ECR_REGISTRY`
- `SERVER_HOST`, `SERVER_USER`, `SERVER_SSH_KEY`

## Backup

Les sauvegardes sont automatiques chaque nuit et incluent :
- Dump complet de la base de données PostgreSQL
- Synchronisation des fichiers utilisateurs vers S3
- Rétention de 7 jours

## Sécurité

- Tous les secrets dans `.env` (jamais committé)
- Conteneurs exécutés en utilisateur non-root (www-data uid 33)
- WAF ModSecurity (OWASP CRS) activé
- Headers de sécurité HTTP configurés
- Réseaux Docker isolés (frontend / backend / monitoring)
