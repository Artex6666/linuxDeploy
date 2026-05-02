#!/usr/bin/env bash
set -euo pipefail

############################################
# setup_firewall.sh
# - Installe iptables
# - Déploie firewall-script.sh vers /usr/local/sbin/
# - Crée et active le service systemd firewall-rules
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

# firewall-script.sh est à la racine du projet (un niveau au-dessus de src/)
FIREWALL_SCRIPT_SRC="${SCRIPT_DIR}/../firewall-script.sh"

log() {
  echo "[INFO] $*"
}

setup_firewall() {
  log "Installation d'iptables..."
  apt-get update -y
  apt-get install -y iptables

  log "Déploiement du script firewall vers ${FIREWALL_SCRIPT}..."
  cp "${FIREWALL_SCRIPT_SRC}" "${FIREWALL_SCRIPT}"
  chmod +x "${FIREWALL_SCRIPT}"

  log "Création du service systemd ${FIREWALL_SERVICE}..."
  cat > "${FIREWALL_SERVICE}" <<EOF
[Unit]
Description=Custom iptables firewall rules
After=network.target

[Service]
Type=oneshot
ExecStart=${FIREWALL_SCRIPT}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable firewall-rules.service
  systemctl start firewall-rules.service

  log "Pare-feu iptables installé et activé."
}

main() {
  setup_firewall
  log "setup_firewall.sh terminé."
}

main "$@"
