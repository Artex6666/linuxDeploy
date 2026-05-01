#!/usr/bin/env bash

# Configuration commune pour la base PostgreSQL du projet

# Nom du conteneur Docker PostgreSQL
PG_CONTAINER_NAME="postgres-db"

# Image PostgreSQL utilisée
PG_IMAGE="postgres:16"

# Paramètres de la base de données exigés par le sujet
PG_DB_NAME="data-db"
PG_DB_USER="dbuser"
PG_DB_PASSWORD="gTU1ZwxE92Z77H83a33OZ046"

# Port exposé sur la VM
PG_PORT="5432"

# Nom du volume Docker pour persister les données
PG_VOLUME_NAME="pgdata_data_db"

# Paramètres de backup PostgreSQL
PG_BACKUP_DIR="/opt/backup/postgresql"
PG_BACKUP_SCRIPT="/usr/local/sbin/pg_backup_docker.sh"

# Pare-feu
FIREWALL_SCRIPT="/usr/local/sbin/firewall-script.sh"
FIREWALL_SERVICE="/etc/systemd/system/firewall-rules.service"

# FTP / SFTP (vsftpd)
FTP_USER="sftpuser"
FTP_PASSWORD="ChangeMe123!"     # à changer pour la démo
FTP_ROOT_DIR="/srv/sftp-data"
VSFTPD_CONF="/etc/vsftpd.conf"
VSFTPD_SSL_DIR="/etc/ssl/vsftpd"
VSFTPD_CERT="${VSFTPD_SSL_DIR}/vsftpd.crt"
VSFTPD_KEY="${VSFTPD_SSL_DIR}/vsftpd.key"

