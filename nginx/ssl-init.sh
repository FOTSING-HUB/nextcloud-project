#!/bin/sh
# Génère un certificat self-signed si absent
# Exécuté au démarrage du conteneur nginx

CERT_DIR="/etc/nginx/certs"
CERT="$CERT_DIR/fullchain.pem"
KEY="$CERT_DIR/privkey.pem"

if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
    echo "[ssl-init] Génération du certificat self-signed..."
    mkdir -p "$CERT_DIR"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY" \
        -out "$CERT" \
        -subj "/C=FR/ST=IDF/L=Paris/O=Nextcloud/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
    echo "[ssl-init] Certificat généré : $CERT"
else
    echo "[ssl-init] Certificat existant trouvé, skip."
fi
