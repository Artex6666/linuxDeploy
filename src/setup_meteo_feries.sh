#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

METEO_DEST="/usr/local/sbin/meteo.sh"
FERIES_DEST="/usr/local/bin/jours_feries.sh"

log() { echo "[INFO] $*"; }

############################################
# 1. Dépendances
############################################

install_deps() {
  apt-get update -y
  apt-get install -y curl jq
}

############################################
# 2. Météo
############################################

setup_meteo() {
  cp "${SCRIPT_DIR}/meteo.sh" "${METEO_DEST}"
  chmod +x "${METEO_DEST}"

  CRON_LINE="0 6 * * * ${METEO_DEST}"
  (crontab -l 2>/dev/null | grep -v "${METEO_DEST}" || true; echo "${CRON_LINE}") | crontab -
  log "Cron météo installé."
}

############################################
# 3. Jours fériés
############################################

setup_jours_feries() {
  cp "${SCRIPT_DIR}/jours_feries.sh" "${FERIES_DEST}"
  chmod +x "${FERIES_DEST}"
}

main() {
  install_deps
  setup_meteo
  setup_jours_feries
}

main "$@"
