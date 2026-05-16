#!/bin/bash
# ==============================================================
# Script de sauvegarde automatique - Nextcloud -> AWS S3
# Exécuté par cron toutes les nuits (configurer dans docker-compose)
# ==============================================================

set -euo pipefail

# --- Variables (chargées depuis l'environnement) ---
BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="/tmp/nextcloud-backup-${BACKUP_DATE}"
S3_BUCKET="${AWS_S3_BUCKET}"
S3_PREFIX="nextcloud-backups"
RETENTION_DAYS=7    # Garder 7 jours de sauvegardes

# Chemins des données Nextcloud
NEXTCLOUD_DATA="/var/www/html/data"
NEXTCLOUD_CONFIG="/var/www/html/config"

echo "========================================"
echo "[$(date)] Démarrage de la sauvegarde"
echo "========================================"

# --- Fonction de log ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERREUR: $1" >&2
    exit 1
}

# --- 1. Créer le répertoire de travail temporaire ---
mkdir -p "${BACKUP_DIR}"
log "Répertoire temporaire créé : ${BACKUP_DIR}"

# --- 2. Sauvegarde de la base de données PostgreSQL ---
log "Dump PostgreSQL en cours..."
PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
    -h postgres \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    --format=custom \
    --no-acl \
    --no-owner \
    -f "${BACKUP_DIR}/nextcloud_db_${BACKUP_DATE}.dump" \
    || error_exit "Échec du dump PostgreSQL"

log "Dump PostgreSQL terminé : $(du -sh ${BACKUP_DIR}/*.dump | cut -f1)"

# --- 3. Sauvegarde des fichiers de configuration ---
log "Sauvegarde de la configuration..."
tar -czf "${BACKUP_DIR}/nextcloud_config_${BACKUP_DATE}.tar.gz" \
    -C / \
    "${NEXTCLOUD_CONFIG#/}" \
    || error_exit "Échec de la sauvegarde de la configuration"

# --- 4. Sauvegarde des fichiers utilisateurs (incrémentale via rclone) ---
log "Synchronisation des fichiers utilisateurs vers S3..."
rclone sync \
    "${NEXTCLOUD_DATA}" \
    "s3:${S3_BUCKET}/${S3_PREFIX}/data/latest/" \
    --config /backup/rclone.conf \
    --transfers 4 \
    --checkers 8 \
    --fast-list \
    --log-level INFO \
    || error_exit "Échec de la sync rclone"

# --- 5. Upload des fichiers de backup vers S3 ---
log "Upload du dump DB et config vers S3..."
rclone copy \
    "${BACKUP_DIR}/" \
    "s3:${S3_BUCKET}/${S3_PREFIX}/snapshots/${BACKUP_DATE}/" \
    --config /backup/rclone.conf \
    --log-level INFO \
    || error_exit "Échec de l'upload vers S3"

# --- 6. Nettoyage des anciennes sauvegardes (rétention) ---
log "Nettoyage des sauvegardes de plus de ${RETENTION_DAYS} jours..."
CUTOFF_DATE=$(date -d "${RETENTION_DAYS} days ago" +%Y-%m-%d 2>/dev/null || \
              date -v-${RETENTION_DAYS}d +%Y-%m-%d)

rclone lsd "s3:${S3_BUCKET}/${S3_PREFIX}/snapshots/" \
    --config /backup/rclone.conf | \
    awk '{print $5}' | \
    while read -r folder; do
        if [[ "$folder" < "$CUTOFF_DATE" ]]; then
            log "Suppression ancienne sauvegarde : $folder"
            rclone purge "s3:${S3_BUCKET}/${S3_PREFIX}/snapshots/${folder}" \
                --config /backup/rclone.conf
        fi
    done

# --- 7. Nettoyage local ---
rm -rf "${BACKUP_DIR}"
log "Nettoyage local effectué"

echo "========================================"
log "Sauvegarde terminée avec succès !"
echo "========================================"
