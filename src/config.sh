#!/usr/bin/env bash

DISCORD_WEBHOOK="https://discord.com/api/webhooks/1500509203880607886/323jhx8HkRF6u39qucTdsieAKMFi6xQKx2UTqQU6GGlsstG5cc-Az_S9eTw033xDAE9m"

PG_CONTAINER_NAME="postgres-db"
PG_IMAGE="postgres:16"
PG_DB_NAME="data-db"
PG_DB_USER="dbuser"
PG_DB_PASSWORD="gTU1ZwxE92Z77H83a33OZ046"
PG_PORT="5432"
PG_VOLUME_NAME="pgdata_data_db"
PG_BACKUP_DIR="/opt/backup/postgresql"
PG_BACKUP_SCRIPT="/usr/local/sbin/pg_backup_docker.sh"

FIREWALL_SCRIPT="/usr/local/sbin/firewall-script.sh"
FIREWALL_SERVICE="/etc/systemd/system/firewall-rules.service"

FTP_USER="sftpuser"
FTP_PASSWORD="mdp"
FTP_ROOT_DIR="/srv/sftp-data"
VSFTPD_CONF="/etc/vsftpd.conf"
VSFTPD_SSL_DIR="/etc/ssl/vsftpd"
VSFTPD_CERT="${VSFTPD_SSL_DIR}/vsftpd.crt"
VSFTPD_KEY="${VSFTPD_SSL_DIR}/vsftpd.key"
