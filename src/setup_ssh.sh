#!/usr/bin/env bash
set -euo pipefail

############################################
# setup_ssh.sh
# - Installe et configure OpenSSH
# - Désactive le login root direct
# - Génère une paire de clés ed25519 pour modo
# - Génère ssh-keys.zip à la racine du projet
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
. "${SCRIPT_DIR}/config.sh"

SSH_USER="modo"
SSH_DIR="/home/${SSH_USER}/.ssh"
KEY_FILE="${SSH_DIR}/id_ed25519"
SSHD_CONFIG="/etc/ssh/sshd_config"
ZIP_OUTPUT="${PROJECT_ROOT}/ssh-keys.zip"

log() {
  echo "[INFO] $*"
}

############################################
# 1. Installation
############################################

install_ssh() {
  log "Installation d'openssh-server et zip..."
  apt-get update -y
  apt-get install -y openssh-server zip
  systemctl enable ssh
  systemctl start ssh
}

############################################
# 2. Sécurisation de la config SSH
############################################

configure_sshd() {
  log "Configuration de sshd : désactivation du login root..."

  # Désactiver le login root direct (exigé par le sujet)
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "${SSHD_CONFIG}"

  # S'assurer que l'auth par clé est activée
  sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "${SSHD_CONFIG}"

  # Autoriser l'auth par mot de passe (pour la démo en soutenance)
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "${SSHD_CONFIG}"

  systemctl restart ssh
  log "sshd reconfiguré et redémarré."
}

############################################
# 3. Génération de la paire de clés pour modo
############################################

generate_keys() {
  log "Création du dossier ${SSH_DIR}..."
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
  chown "${SSH_USER}:${SSH_USER}" "${SSH_DIR}"

  if [ -f "${KEY_FILE}" ]; then
    log "Paire de clés déjà existante, on la garde."
  else
    log "Génération d'une paire de clés ed25519 pour ${SSH_USER}..."
    sudo -u "${SSH_USER}" ssh-keygen -t ed25519 \
      -f "${KEY_FILE}" \
      -C "${SSH_USER}@linux-exam-vm" \
      -N ""
    log "Clés générées : ${KEY_FILE} et ${KEY_FILE}.pub"
  fi

  # Ajouter la clé publique aux authorized_keys
  if ! grep -qF "$(cat "${KEY_FILE}.pub")" "${SSH_DIR}/authorized_keys" 2>/dev/null; then
    cat "${KEY_FILE}.pub" >> "${SSH_DIR}/authorized_keys"
    log "Clé publique ajoutée à authorized_keys."
  fi

  chmod 600 "${SSH_DIR}/authorized_keys"
  chown "${SSH_USER}:${SSH_USER}" "${SSH_DIR}/authorized_keys"
}

############################################
# 4. Génération du ssh-keys.zip à la racine
############################################

generate_zip() {
  log "Génération de ${ZIP_OUTPUT}..."

  # Crée le zip avec les deux clés (privée + publique)
  zip -j "${ZIP_OUTPUT}" "${KEY_FILE}" "${KEY_FILE}.pub"

  log "ssh-keys.zip généré : ${ZIP_OUTPUT}"
  log "  → id_ed25519      (clé privée — à garder secrète)"
  log "  → id_ed25519.pub  (clé publique)"
}

############################################
# Main
############################################

main() {
  install_ssh
  configure_sshd
  generate_keys
  generate_zip
  log "setup_ssh.sh terminé."
}

main "$@"
