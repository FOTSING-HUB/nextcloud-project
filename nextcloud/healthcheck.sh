#!/bin/bash
# Healthcheck Nextcloud - vérifie que le service répond correctement
curl -sf http://localhost/status.php | grep -q '"installed":true' || exit 1
