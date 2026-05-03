#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

FLUTTER_SDK="/opt/flutter"
FLUTTER_USER="modo"
CHECK_SCRIPT="/usr/local/sbin/flutter_check.sh"
SERVICE_FILE="/etc/systemd/system/flutter-integrity.service"
TIMER_FILE="/etc/systemd/system/flutter-integrity.timer"

log() { echo "[INFO] $*"; }

############################################
# 1. Dépendances
############################################

install_deps() {
  apt-get update -y
  apt-get install -y curl git unzip xz-utils
}

############################################
# 2. SDK Flutter
############################################

install_flutter() {
  if [ -d "${FLUTTER_SDK}" ]; then
    log "SDK Flutter déjà présent."
    return
  fi

  git clone https://github.com/flutter/flutter.git -b stable "${FLUTTER_SDK}"
  chown -R "${FLUTTER_USER}:${FLUTTER_USER}" "${FLUTTER_SDK}"

  git config --global --add safe.directory "${FLUTTER_SDK}" || true
  sudo -u "${FLUTTER_USER}" git config --global --add safe.directory "${FLUTTER_SDK}" || true

  sudo -u "${FLUTTER_USER}" "${FLUTTER_SDK}/bin/flutter" precache || true
  log "SDK Flutter installé."
}

############################################
# 3. Script de vérification
############################################

deploy_check_script() {
  sed "s|__DISCORD_WEBHOOK__|${DISCORD_WEBHOOK}|g" \
    "${SCRIPT_DIR}/flutter_check.sh" > "${CHECK_SCRIPT}"
  chmod +x "${CHECK_SCRIPT}"
}

############################################
# 4. Service systemd
############################################

setup_systemd() {
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
  log "Service flutter-integrity activé."
}

main() {
  install_deps
  install_flutter
  deploy_check_script
  setup_systemd

  log "Vérification immédiate..."
  sudo -u "${FLUTTER_USER}" bash "${CHECK_SCRIPT}" || true
}

main "$@"
