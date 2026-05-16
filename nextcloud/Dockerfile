# ==============================================================
# Image Nextcloud personnalisée
# Base : nextcloud:27-fpm-alpine (légère, sécurisée)
# Ajouts : extensions PHP, outils, configuration non-root
# ==============================================================
FROM nextcloud:27-fpm-alpine

LABEL maintainer="votre-email@example.com"
LABEL description="Nextcloud custom image - Cloud personnel TP"

# --- Passage en root temporairement pour les installations ---
USER root

# --- Installation des dépendances supplémentaires ---
RUN apk add --no-cache \
    ffmpeg \
    imagemagick \
    ghostscript \
    bash \
    curl \
    && rm -rf /var/cache/apk/*

# --- Extensions PHP supplémentaires ---
RUN apk add --no-cache \
    php82-pecl-imagick \
    php82-pecl-redis \
    && docker-php-ext-enable imagick

# --- Configuration PHP optimisée ---
RUN { \
    echo "memory_limit=${PHP_MEMORY_LIMIT:-512M}"; \
    echo "upload_max_filesize=${PHP_UPLOAD_LIMIT:-10G}"; \
    echo "post_max_size=${PHP_UPLOAD_LIMIT:-10G}"; \
    echo "max_execution_time=3600"; \
    echo "max_input_time=3600"; \
    echo "output_buffering=off"; \
} > /usr/local/etc/php/conf.d/nextcloud-custom.ini

# --- Script de healthcheck ---
COPY --chown=www-data:www-data healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

# --- Correction des permissions sur les dossiers critiques ---
RUN mkdir -p /var/www/html/data /var/www/html/config /var/www/html/custom_apps \
    && chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /usr/local/etc/php/conf.d

# --- Retour à l'utilisateur non-root www-data (uid 33) ---
USER www-data

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD php-fpm -t 2>&1 | grep -q 'successful' || kill -0 1
