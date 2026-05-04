#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

log() { echo "[INFO] $*"; }

############################################
# Attente PostgreSQL
############################################

wait_for_postgres() {
  log "Attente de PostgreSQL..."
  for i in $(seq 1 20); do
    if docker exec "${PG_CONTAINER_NAME}" pg_isready -U "${PG_DB_USER}" >/dev/null 2>&1; then
      log "PostgreSQL prêt."
      return
    fi
    sleep 3
  done
  echo "PostgreSQL inaccessible après 60s." >&2
  exit 1
}

############################################
# Création du schéma
############################################

create_schema() {
  log "Création des tables..."

  docker exec -i "${PG_CONTAINER_NAME}" psql -U "${PG_DB_USER}" -d "${PG_DB_NAME}" <<SQL
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS events (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  date TIMESTAMP WITH TIME ZONE NOT NULL,
  location VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS event_participants (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  event_id INT NOT NULL,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
);
SQL

  log "Tables créées."
  docker exec "${PG_CONTAINER_NAME}" psql -U "${PG_DB_USER}" -d "${PG_DB_NAME}" -c "\dt"
}

main() {
  wait_for_postgres
  create_schema
}

main "$@"
