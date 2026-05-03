#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
. "${SCRIPT_DIR}/config.sh"

SSH_USER="modo"
SSH_DIR="/home/${SSH_USER}/.ssh"
KEY_FILE="${SSH_DIR}/id_ed25519"
SSHD_CONFIG="/etc/ssh/sshd_config"

log() { echo "[INFO] $*"; }

############################################
# 1. Installation
############################################

install_ssh() {
  apt-get update -y
  apt-get install -y openssh-server zip
  systemctl enable ssh && systemctl start ssh
}

############################################
# 2. Configuration sshd
############################################

configure_sshd() {
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "${SSHD_CONFIG}"
  sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "${SSHD_CONFIG}"
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "${SSHD_CONFIG}"
  systemctl restart ssh
  log "sshd reconfiguré."
}

############################################
# 3. Clés SSH pour modo
############################################

generate_keys() {
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
  chown "${SSH_USER}:${SSH_USER}" "${SSH_DIR}"

  if [ ! -f "${KEY_FILE}" ]; then
    sudo -u "${SSH_USER}" ssh-keygen -t ed25519 -f "${KEY_FILE}" -C "${SSH_USER}@linux-exam-vm" -N ""
  fi

  if ! grep -qF "$(cat "${KEY_FILE}.pub")" "${SSH_DIR}/authorized_keys" 2>/dev/null; then
    cat "${KEY_FILE}.pub" >> "${SSH_DIR}/authorized_keys"
  fi

  chmod 600 "${SSH_DIR}/authorized_keys"
  chown "${SSH_USER}:${SSH_USER}" "${SSH_DIR}/authorized_keys"
}

############################################
# 4. ssh-keys.zip
############################################

generate_zip() {
  zip -j "${PROJECT_ROOT}/ssh-keys.zip" "${KEY_FILE}" "${KEY_FILE}.pub"
  log "ssh-keys.zip généré."
}

main() {
  install_ssh
  configure_sshd
  generate_keys
  generate_zip
}

main "$@"
