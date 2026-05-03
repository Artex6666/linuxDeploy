#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -ne 0 ] && echo "Lancer en root (sudo)." >&2 && exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"
. "${SRC_DIR}/config.sh"

log() { echo "[INFO] $*"; }

run_script() {
  local script="${SRC_DIR}/$1"
  if [ -f "$script" ]; then
    log "-> $1"
    bash "$script"
  else
    log "-> $1 non trouvé, skip."
  fi
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker déjà installé."
    return
  fi

  log "Installation de Docker..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release

  install -m 0755 -d /etc/apt/keyrings
  [ ! -f /etc/apt/keyrings/docker.gpg ] && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg

  UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME}")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker && systemctl start docker
  log "Docker installé."
}

deploy_postgres() {
  if ! docker volume ls --format '{{.Name}}' | grep -qx "${PG_VOLUME_NAME}"; then
    docker volume create "${PG_VOLUME_NAME}" >/dev/null
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "${PG_CONTAINER_NAME}"; then
    docker rm -f "${PG_CONTAINER_NAME}" >/dev/null || true
  fi

  log "Lancement de PostgreSQL..."
  docker run -d \
    --name "${PG_CONTAINER_NAME}" \
    -e POSTGRES_DB="${PG_DB_NAME}" \
    -e POSTGRES_USER="${PG_DB_USER}" \
    -e POSTGRES_PASSWORD="${PG_DB_PASSWORD}" \
    -p "${PG_PORT}:5432" \
    -v "${PG_VOLUME_NAME}:/var/lib/postgresql/data" \
    --restart unless-stopped \
    "${PG_IMAGE}"
}

main() {
  install_docker
  deploy_postgres
  run_script setup_ssh.sh
  run_script setup_firewall.sh
  run_script setup_sftp.sh
  run_script setup_meteo_feries.sh
  run_script setup_flutter.sh
  log "Terminé."
}

main "$@"
