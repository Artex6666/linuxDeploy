#!/usr/bin/env bash
set -euo pipefail

############################################
# setup_meteo_feries.sh
# - Installe curl et jq
# - Déploie meteo.sh → /usr/local/sbin/
# - Déploie jours_feries.sh → /usr/local/bin/
# - Configure le cron météo (tous les jours à 06h00)
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

log() {
  echo "[INFO] $*"
}

METEO_DEST="/usr/local/sbin/meteo.sh"
FERIES_DEST="/usr/local/bin/jours_feries.sh"

############################################
# 1. Installation des dépendances
############################################

install_deps() {
  log "Installation des dépendances (curl, jq)..."
  apt-get update -y
  apt-get install -y curl jq
}

############################################
# 2. Déploiement du script météo + cron
############################################

setup_meteo() {
  log "Déploiement du script météo vers ${METEO_DEST}..."
  cp "${SCRIPT_DIR}/meteo.sh" "${METEO_DEST}"
  chmod +x "${METEO_DEST}"

  log "Configuration du cron météo (tous les jours à 06h00)..."
  CRON_LINE="0 6 * * * ${METEO_DEST}"
  (crontab -l 2>/dev/null | grep -v "${METEO_DEST}" || true; echo "${CRON_LINE}") | crontab -
  log "Cron météo installé."
}

############################################
# 3. Déploiement du script jours fériés
############################################

setup_jours_feries() {
  log "Déploiement du script jours fériés vers ${FERIES_DEST}..."
  cp "${SCRIPT_DIR}/jours_feries.sh" "${FERIES_DEST}"
  chmod +x "${FERIES_DEST}"
  log "Script jours fériés disponible via : jours_feries.sh"
}

############################################
# Main
############################################

main() {
  install_deps
  setup_meteo
  setup_jours_feries
  log "setup_meteo_feries.sh terminé."
}

main "$@"
