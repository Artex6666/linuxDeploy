#!/usr/bin/env bash
set -euo pipefail

############################################
# Partie de Loris
############################################

############################################
# Configuration commune
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

log() {
  echo "[INFO] $*"
}

############################################
# 1. Installation des paquets nécessaires
############################################

install_packages() {
  log "Installation paquets: vsftpd, iptables, cron (et docker-cli si besoin)..."
  apt-get update -y
  apt-get install -y vsftpd iptables cron openssl

  # docker CLI devrait déjà être là via run-all.sh, mais on sécurise
  if ! command -v docker >/dev/null 2>&1; then
    log "Docker CLI absent, installation rapide..."
    apt-get install -y docker.io || true
  fi

  systemctl enable cron
  systemctl start cron
}

############################################
# 2. Script de firewall + service systemd
############################################

setup_firewall() {
  log "Création du script firewall ${FIREWALL_SCRIPT}..."

  cat > "${FIREWALL_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Default policies
# INPUT: drop all incoming traffic by default for security
iptables -P INPUT DROP
# FORWARD: drop forwarded traffic (this server is not a router)
iptables -P FORWARD DROP
# OUTPUT: allow all outgoing traffic (server can reach the Internet)
iptables -P OUTPUT ACCEPT

# Allow loopback interface traffic (local processes communication)
iptables -A INPUT -i lo -j ACCEPT

# Allow established and related connections (keep existing connections working)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (remote administration)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP and HTTPS (web server access if needed)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow PostgreSQL external access (exam requirement)
iptables -A INPUT -p tcp --dport 5432 -j ACCEPT

# Allow FTP (vsftpd) control port
iptables -A INPUT -p tcp --dport 21 -j ACCEPT

# Allow FTP passive ports (for data connections)
iptables -A INPUT -p tcp --dport 30000:31000 -j ACCEPT

# Optionally allow ICMP (ping) for network diagnostics
iptables -A INPUT -p icmp -j ACCEPT
EOF

  chmod +x "${FIREWALL_SCRIPT}"

  log "Création du service systemd firewall ${FIREWALL_SERVICE}..."

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

############################################
# 3. Script de backup PostgreSQL + cron
############################################

setup_pg_backup() {
  log "Création du répertoire de backup ${PG_BACKUP_DIR}..."
  mkdir -p "${PG_BACKUP_DIR}"
  chmod 700 "${PG_BACKUP_DIR}"

  log "Création du script de backup ${PG_BACKUP_SCRIPT}..."

  cat > "${PG_BACKUP_SCRIPT}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=\$(date +%F-%H%M%S)
BACKUP_FILE="${PG_BACKUP_DIR}/${PG_DB_NAME}-\${TIMESTAMP}.sql"

# On suppose que le conteneur PostgreSQL s'appelle ${PG_CONTAINER_NAME}
docker exec -e PGPASSWORD="${PG_DB_PASSWORD}" ${PG_CONTAINER_NAME} \
  pg_dump -U "${PG_DB_USER}" -d "${PG_DB_NAME}" > "\${BACKUP_FILE}"
EOF

  chmod +x "${PG_BACKUP_SCRIPT}"

  log "Configuration du cron pour backup PostgreSQL tous les 2 jours à 02:04..."

  CRON_LINE="4 2 */2 * * ${PG_BACKUP_SCRIPT}"

  (crontab -l 2>/dev/null | grep -v "${PG_BACKUP_SCRIPT}" || true; echo "${CRON_LINE}") | crontab -

  log "Cron de backup PostgreSQL installé."
}

############################################
# 4. Serveur vsftpd (FTP/FTPS cloisonné)
############################################

setup_vsftpd() {
  log "Création du dossier racine FTP ${FTP_ROOT_DIR}..."
  mkdir -p "${FTP_ROOT_DIR}"
  chmod 755 "${FTP_ROOT_DIR}"

  log "Création de l'utilisateur ${FTP_USER}..."
  if ! id "${FTP_USER}" >/dev/null 2>&1; then
    useradd -d "${FTP_ROOT_DIR}" -s /usr/sbin/nologin "${FTP_USER}"
    echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd
  else
    log "Utilisateur ${FTP_USER} déjà existant, on le garde."
  fi

  chown -R "${FTP_USER}:${FTP_USER}" "${FTP_ROOT_DIR}"

  log "Configuration de vsftpd..."

  if [ -f "${VSFTPD_CONF}" ] && [ ! -f "${VSFTPD_CONF}.orig" ]; then
    cp "${VSFTPD_CONF}" "${VSFTPD_CONF}.orig"
  fi

  mkdir -p "${VSFTPD_SSL_DIR}"

  if [ ! -f "${VSFTPD_CERT}" ] || [ ! -f "${VSFTPD_KEY}" ]; then
    log "Génération d'un certificat auto-signé pour FTPS..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "${VSFTPD_KEY}" -out "${VSFTPD_CERT}" \
      -subj "/C=FR/ST=IDF/L=Paris/O=Exam/OU=Linux/CN=linux-exam-vm"
    chmod 600 "${VSFTPD_KEY}"
    chmod 644 "${VSFTPD_CERT}"
  fi

  cat > "${VSFTPD_CONF}" <<EOF
listen=YES
listen_ipv6=NO

anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022

dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

chroot_local_user=YES
allow_writeable_chroot=YES

pam_service_name=vsftpd
userlist_enable=YES
userlist_deny=NO
userlist_file=/etc/vsftpd.user_list

pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000

ssl_enable=YES
allow_anon_ssl=NO
force_local_logins_ssl=YES
force_local_data_ssl=YES
rsa_cert_file=${VSFTPD_CERT}
rsa_private_key_file=${VSFTPD_KEY}
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO

seccomp_sandbox=NO

listen_port=21
EOF

  echo "${FTP_USER}" > /etc/vsftpd.user_list

  systemctl enable vsftpd
  systemctl restart vsftpd

  log "vsftpd configuré. Utilisateur: ${FTP_USER}, dossier: ${FTP_ROOT_DIR}"
  log "Mot de passe FTP actuel: ${FTP_PASSWORD}"
}

############################################
# Main
############################################

main() {
  install_packages
  setup_firewall
  setup_pg_backup
  setup_vsftpd

  log "setup_sftp_firewall_backup.sh terminé."
}

main "$@"