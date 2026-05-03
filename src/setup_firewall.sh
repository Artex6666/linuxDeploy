#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

FIREWALL_SCRIPT_SRC="${SCRIPT_DIR}/firewall-script.sh"

log() { echo "[INFO] $*"; }

############################################
# Firewall
############################################

setup_firewall() {
  apt-get update -y
  apt-get install -y iptables

  cp "${FIREWALL_SCRIPT_SRC}" "${FIREWALL_SCRIPT}"
  chmod +x "${FIREWALL_SCRIPT}"

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
  log "Pare-feu activé."
}

main() {
  setup_firewall
}

main "$@"
