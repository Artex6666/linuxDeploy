#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

log() { echo "[INFO] $*"; }

############################################
# 1. Paquets
############################################

install_packages() {
  apt-get update -y
  apt-get install -y vsftpd cron openssl

  if ! command -v docker >/dev/null 2>&1; then
    apt-get install -y docker.io || true
  fi

  systemctl enable cron && systemctl start cron
}

############################################
# 2. Backup PostgreSQL
############################################

setup_pg_backup() {
  mkdir -p "${PG_BACKUP_DIR}"
  chmod 700 "${PG_BACKUP_DIR}"

  cat > "${PG_BACKUP_SCRIPT}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=\$(date +%F-%H%M%S)
BACKUP_FILE="${PG_BACKUP_DIR}/${PG_DB_NAME}-\${TIMESTAMP}.sql"

docker exec -e PGPASSWORD="${PG_DB_PASSWORD}" ${PG_CONTAINER_NAME} \
  pg_dump -U "${PG_DB_USER}" -d "${PG_DB_NAME}" > "\${BACKUP_FILE}"
EOF

  chmod +x "${PG_BACKUP_SCRIPT}"

  CRON_LINE="4 2 */2 * * ${PG_BACKUP_SCRIPT}"
  (crontab -l 2>/dev/null | grep -v "${PG_BACKUP_SCRIPT}" || true; echo "${CRON_LINE}") | crontab -
  log "Cron backup PostgreSQL installé."
}

############################################
# 3. vsftpd
############################################

setup_vsftpd() {
  mkdir -p "${FTP_ROOT_DIR}"
  chmod 755 "${FTP_ROOT_DIR}"

  if ! id "${FTP_USER}" >/dev/null 2>&1; then
    useradd -d "${FTP_ROOT_DIR}" -s /usr/sbin/nologin "${FTP_USER}"
    echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd
  fi

  chown -R "${FTP_USER}:${FTP_USER}" "${FTP_ROOT_DIR}"

  if ! grep -qx "/usr/sbin/nologin" /etc/shells; then
    echo "/usr/sbin/nologin" >> /etc/shells
  fi

  [ -f "${VSFTPD_CONF}" ] && [ ! -f "${VSFTPD_CONF}.orig" ] && cp "${VSFTPD_CONF}" "${VSFTPD_CONF}.orig"

  mkdir -p "${VSFTPD_SSL_DIR}"

  if [ ! -f "${VSFTPD_CERT}" ] || [ ! -f "${VSFTPD_KEY}" ]; then
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
  systemctl enable vsftpd && systemctl restart vsftpd
  log "vsftpd configuré."
}

############################################
# 4. sftp-identifiers.txt
############################################

generate_sftp_identifiers() {
  cat > "${SCRIPT_DIR}/../sftp-identifiers.txt" <<EOF
User: ${FTP_USER}
Password: ${FTP_PASSWORD}
Directory: ${FTP_ROOT_DIR}
Port: 21
EOF
}

main() {
  install_packages
  setup_pg_backup
  setup_vsftpd
  generate_sftp_identifiers
}

main "$@"
