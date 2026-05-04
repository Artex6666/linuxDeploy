#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

APP_DIR="/opt/strapi"
APP_PORT="1337"
STRAPI_USER="modo"
SERVICE_FILE="/etc/systemd/system/strapi.service"

log() { echo "[INFO] $*"; }

############################################
# 1. Node.js + Nginx
############################################

install_deps() {
  apt-get update -y
  apt-get install -y nginx curl

  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi

  log "Node $(node -v) installé."
}

############################################
# 2. Strapi
############################################

install_strapi() {
  if [ -d "${APP_DIR}" ]; then
    log "Strapi déjà installé."
    return
  fi

  log "Création du projet Strapi (peut prendre quelques minutes)..."

  sudo -u "${STRAPI_USER}" env \
    DATABASE_CLIENT=postgres \
    DATABASE_HOST=127.0.0.1 \
    DATABASE_PORT="${PG_PORT}" \
    DATABASE_NAME="${PG_DB_NAME}" \
    DATABASE_USERNAME="${PG_DB_USER}" \
    DATABASE_PASSWORD="${PG_DB_PASSWORD}" \
    npx create-strapi-app@latest "${APP_DIR}" --no-run --skip-cloud --ts=false

  chown -R "${STRAPI_USER}:${STRAPI_USER}" "${APP_DIR}"
  log "Strapi installé dans ${APP_DIR}."
}

############################################
# 3. Content type Article
############################################

create_content_types() {
  ARTICLE_DIR="${APP_DIR}/src/api/article/content-types/article"
  mkdir -p "${ARTICLE_DIR}"

  cat > "${ARTICLE_DIR}/schema.json" <<'EOF'
{
  "kind": "collectionType",
  "collectionName": "articles",
  "info": {
    "singularName": "article",
    "pluralName": "articles",
    "displayName": "Article"
  },
  "options": { "draftAndPublish": true },
  "attributes": {
    "title": { "type": "string", "required": true },
    "content": { "type": "richtext" },
    "author": {
      "type": "relation",
      "relation": "manyToOne",
      "target": "plugin::users-permissions.user",
      "inversedBy": "articles"
    }
  }
}
EOF

  chown -R "${STRAPI_USER}:${STRAPI_USER}" "${APP_DIR}/src/api"
  log "Content type Article créé."
}

############################################
# 4. Build Strapi
############################################

build_strapi() {
  log "Build de l'admin Strapi..."
  sudo -u "${STRAPI_USER}" bash -c "cd ${APP_DIR} && NODE_ENV=production npm run build"
}

############################################
# 5. Service systemd
############################################

setup_service() {
  cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Strapi CMS
After=network.target

[Service]
Type=simple
User=${STRAPI_USER}
WorkingDirectory=${APP_DIR}
Environment=NODE_ENV=production
Environment=DATABASE_CLIENT=postgres
Environment=DATABASE_HOST=127.0.0.1
Environment=DATABASE_PORT=${PG_PORT}
Environment=DATABASE_NAME=${PG_DB_NAME}
Environment=DATABASE_USERNAME=${PG_DB_USER}
Environment=DATABASE_PASSWORD=${PG_DB_PASSWORD}
ExecStart=/usr/bin/node node_modules/.bin/strapi start
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable strapi
  systemctl start strapi
  log "Service Strapi démarré."
}

############################################
# 6. Nginx reverse proxy
############################################

setup_nginx() {
  cat > /etc/nginx/sites-available/strapi <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/strapi /etc/nginx/sites-enabled/strapi
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl restart nginx
  log "Nginx configuré."
}

############################################
# 7. app-web.txt
############################################

generate_app_web() {
  VM_IP=$(hostname -I | awk '{print $1}')
  cat > "${SCRIPT_DIR}/../app-web.txt" <<EOF
URL: http://${VM_IP}
Admin: http://${VM_IP}/admin
Port Strapi: ${APP_PORT} (exposé via Nginx sur le port 80)
EOF
  log "app-web.txt généré."
}

main() {
  install_deps
  install_strapi
  create_content_types
  build_strapi
  setup_service
  setup_nginx
  generate_app_web
}

main "$@"
