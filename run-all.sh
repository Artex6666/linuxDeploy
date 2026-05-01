#!/usr/bin/env bash
set -euo pipefail

########################################
# Vérifications de base
########################################

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERREUR] Ce script doit être exécuté en root (sudo)." >&2
  exit 1
fi

########################################
# Variables globales
########################################

# On charge la configuration commune (PostgreSQL, etc.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

########################################
# Fonctions utilitaires
########################################

log() {
  echo "[INFO] $*"
}

########################################
# Installation de Docker
########################################

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker est déjà installé, on continue."
    return
  fi

  log "Installation de Docker (engine + CLI + compose-plugin)..."

  apt-get update -y
  apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  # Clé GPG Docker
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  # Dépôt Docker
  UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME}")"
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    ${UBUNTU_CODENAME} stable" > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable docker
  systemctl start docker

  log "Docker installé et démarré."
}

########################################
# Déploiement de PostgreSQL 16 en Docker
########################################

deploy_postgres_container() {
  log "Préparation du volume Docker pour PostgreSQL..."
  if ! docker volume ls --format '{{.Name}}' | grep -qx "${PG_VOLUME_NAME}"; then
    docker volume create "${PG_VOLUME_NAME}" >/dev/null
    log "Volume ${PG_VOLUME_NAME} créé."
  else
    log "Volume ${PG_VOLUME_NAME} déjà existant."
  fi

  # Si un conteneur avec ce nom existe déjà, on le supprime proprement
  if docker ps -a --format '{{.Names}}' | grep -qx "${PG_CONTAINER_NAME}"; then
    log "Un conteneur ${PG_CONTAINER_NAME} existe déjà, on le supprime..."
    docker rm -f "${PG_CONTAINER_NAME}" >/dev/null || true
  fi

  log "Lancement du conteneur PostgreSQL ${PG_CONTAINER_NAME}..."

  docker run -d \
    --name "${PG_CONTAINER_NAME}" \
    -e POSTGRES_DB="${PG_DB_NAME}" \
    -e POSTGRES_USER="${PG_DB_USER}" \
    -e POSTGRES_PASSWORD="${PG_DB_PASSWORD}" \
    -p "${PG_PORT}:5432" \
    -v "${PG_VOLUME_NAME}:/var/lib/postgresql/data" \
    --restart unless-stopped \
    "${PG_IMAGE}"

  log "Conteneur PostgreSQL lancé."
  log "Détails connexion :"
  log "  Host : IP de la VM"
  log "  Port : ${PG_PORT}"
  log "  DB   : ${PG_DB_NAME}"
  log "  User : ${PG_DB_USER}"
  log "  Pass : ${PG_DB_PASSWORD}"
}

########################################
# Hooks pour les autres parties du projet
########################################

run_other_scripts() {
  log "Exécution des autres scripts du projet si présents et exécutables..."

  # Exemple : script pour la partie SSH
  if [ -x "${SCRIPT_DIR}/setup_ssh.sh" ]; then
    log "-> Execution de ${SCRIPT_DIR}/setup_ssh.sh"
    "${SCRIPT_DIR}/setup_ssh.sh"
  else
    log "-> setup_ssh.sh non trouvé ou non exécutable (ok pour l'instant)."
  fi

  # Exemple : script pour firewall + SFTP + cron backup PostgreSQL
  if [ -x "${SCRIPT_DIR}/setup_sftp_firewall_backup.sh" ]; then
    log "-> Execution de ${SCRIPT_DIR}/setup_sftp_firewall_backup.sh"
    "${SCRIPT_DIR}/setup_sftp_firewall_backup.sh"
  else
    log "-> setup_sftp_firewall_backup.sh non trouvé ou non exécutable (ok pour l'instant)."
  fi

  # Ici tu pourras rajouter d'autres scripts au fur et à mesure du projet :
  # if [ -x "./setup_meteo_cron.sh" ]; then
  #   ./setup_meteo_cron.sh
  # fi
  #
  # if [ -x "./setup_flutter_service.sh" ]; then
  #   ./setup_flutter_service.sh
  # fi
}

########################################
# Main
########################################

main() {
  install_docker
  deploy_postgres_container
  run_other_scripts

  log "run-all.sh terminé."
}

main "$@"