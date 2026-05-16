# Architecture — Nextcloud Cloud Personnel

## Schéma d'architecture

```
                        INTERNET
                           │
                    ┌──────▼──────┐
                    │   Port 80   │  HTTP → redirige vers HTTPS
                    │   Port 443  │  HTTPS (TLS 1.2/1.3)
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │     NGINX + ModSecurity  │  Réseau: frontend
              │   Reverse Proxy / WAF   │
              │   Load Balancer         │
              └────────┬───────┬────────┘
                       │       │  least_conn
              ┌────────▼─┐  ┌──▼────────┐
              │Nextcloud  │  │Nextcloud  │  Réseau: frontend + backend
              │  app1     │  │  app2     │
              │(www-data) │  │(www-data) │
              └────┬──────┘  └──────┬────┘
                   │    (volumes    │
                   │    partagés)   │
              ┌────▼────────────────▼────┐
              │        Réseau: backend    │
              │  ┌──────────┐  ┌───────┐ │
              │  │PostgreSQL│  │ Redis │ │
              │  │   :5432  │  │ :6379 │ │
              │  └──────────┘  └───────┘ │
              └───────────────────────────┘

              ┌───────────────────────────┐
              │     Réseau: monitoring    │
              │  ┌──────────┐  ┌───────┐ │
              │  │Prometheus│  │Grafana│ │
              │  │  :9090   │  │ :3000 │ │
              │  └──────────┘  └───────┘ │
              │  ┌──────────┐  ┌───────┐ │
              │  │   Loki   │  │Promtail│ │
              │  │  :3100   │  │ :9080 │ │
              │  └──────────┘  └───────┘ │
              └───────────────────────────┘

              ┌───────────────────────────┐
              │         Backup            │
              │  nextcloud_cron           │
              │  (backup.sh nuit)         │
              │         │                 │
              │         ▼                 │
              │     AWS S3 Bucket         │
              └───────────────────────────┘
```

## Réseaux Docker

| Réseau     | Services                                      |
|------------|-----------------------------------------------|
| frontend   | nginx, nextcloud_app1, nextcloud_app2         |
| backend    | nextcloud_app1, nextcloud_app2, postgres, redis, nextcloud_cron |
| monitoring | prometheus, grafana, loki, promtail           |

## Volumes persistants

| Volume           | Contenu                        |
|------------------|--------------------------------|
| nextcloud_data   | Fichiers utilisateurs          |
| nextcloud_config | Configuration Nextcloud        |
| nextcloud_apps   | Applications Nextcloud         |
| postgres_data    | Base de données PostgreSQL     |
| redis_data       | Cache Redis                    |
| nginx_certs      | Certificats SSL                |
| prometheus_data  | Métriques Prometheus (15j)     |
| grafana_data     | Dashboards Grafana             |
| loki_data        | Logs centralisés               |

## Flux de données

- **Requête utilisateur** → Nginx (WAF ModSecurity) → Load Balancer → Nextcloud app1 ou app2
- **Données fichiers** → Volume `nextcloud_data` partagé entre app1 et app2
- **Sessions/Cache** → Redis (partagé entre les 2 instances)
- **Base de données** → PostgreSQL (instance unique, partagée)
- **Logs** → Promtail → Loki → Grafana
- **Métriques** → Prometheus (scrape toutes les 15s) → Grafana
- **Backup** → cron nuit → dump PG + sync fichiers → AWS S3

## CI/CD Pipeline

```
Push sur main
     │
     ▼
┌─────────┐    ┌──────────┐    ┌────────────┐
│  Build  │───▶│ Push ECR │───▶│  Deploy    │
│  & Test │    │          │    │  (SSH +    │
│         │    │          │    │  rolling)  │
└─────────┘    └──────────┘    └────────────┘
```

## Sécurité

- TLS 1.2/1.3 uniquement, HSTS activé
- WAF ModSecurity OWASP CRS (mode actif)
- Conteneurs non-root : www-data (uid 33), postgres (uid 70)
- Réseaux Docker isolés — pas d'accès direct DB depuis internet
- Secrets uniquement dans `.env` (jamais commité)
- Headers HTTP de sécurité : HSTS, X-Frame-Options, CSP, etc.
