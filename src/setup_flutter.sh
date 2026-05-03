#!/usr/bin/env bash
set -euo pipefail

############################################
# setup_flutter.sh
# - Installe le SDK Flutter dans /opt/flutter
# - Déploie le script de vérification d'intégrité
# - Crée un service + timer systemd (quotidien)
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

FLUTTER_SDK="/opt/flutter"
FLUTTER_USER="modo"
CHECK_SCRIPT="/usr/local/sbin/flutter_check.sh"
SERVICE_FILE="/etc/systemd/system/flutter-integrity.service"
TIMER_FILE="/etc/systemd/system/flutter-integrity.timer"

log() {
  echo "[INFO] $*"
}

############################################
# 1. Installation des dépendances
############################################

install_deps() {
  log "Installation des dépendances Flutter..."
  apt-get update -y
  apt-get install -y curl git unzip xz-utils
}

############################################
# 2. Installation du SDK Flutter
############################################

install_flutter() {
  if [ -d "${FLUTTER_SDK}" ]; then
    log "SDK Flutter déjà présent dans ${FLUTTER_SDK}."
    return
  fi

  log "Téléchargement et installation du SDK Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable "${FLUTTER_SDK}"
  chown -R "${FLUTTER_USER}:${FLUTTER_USER}" "${FLUTTER_SDK}"

  # Pré-téléchargement des binaires dart
  sudo -u "${FLUTTER_USER}" "${FLUTTER_SDK}/bin/flutter" precache || true
  log "SDK Flutter installé dans ${FLUTTER_SDK}."
}

############################################
# 3. Déploiement du script de vérification
############################################

deploy_check_script() {
  log "Déploiement du script de vérification..."
  sed "s|__DISCORD_WEBHOOK__|${DISCORD_WEBHOOK}|g" \
    "${SCRIPT_DIR}/flutter_check.sh" > "${CHECK_SCRIPT}"
  chmod +x "${CHECK_SCRIPT}"
}

############################################
# 4. Service + timer systemd
############################################

setup_systemd() {
  log "Création du service systemd flutter-integrity..."

  cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Flutter SDK integrity check
After=network.target

[Service]
Type=oneshot
User=${FLUTTER_USER}
ExecStart=${CHECK_SCRIPT}
EOF

  cat > "${TIMER_FILE}" <<EOF
[Unit]
Description=Run Flutter integrity check daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable flutter-integrity.timer
  systemctl start flutter-integrity.timer

  log "Service flutter-integrity activé (quotidien)."
}

############################################
# Main
############################################

main() {
  install_deps
  install_flutter
  deploy_check_script
  setup_systemd

  log "Exécution immédiate du check pour vérification..."
  bash "${CHECK_SCRIPT}" || true

  log "setup_flutter.sh terminé."
}

main "$@"
