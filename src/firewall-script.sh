#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# firewall-script.sh — Custom iptables rules
# Executed at boot via systemd (firewall-rules.service)
# ============================================================

# Flush all existing rules and chains
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# --- Default policies ---
# Drop all incoming traffic by default (whitelist approach)
iptables -P INPUT DROP
# Drop forwarded traffic (this server is not a router)
iptables -P FORWARD DROP
# Allow all outgoing traffic (server needs to reach the internet)
iptables -P OUTPUT ACCEPT

# --- Loopback ---
# Allow local processes to communicate with each other
iptables -A INPUT -i lo -j ACCEPT

# --- Stateful connections ---
# Allow packets belonging to already established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# --- SSH (port 22) ---
# Allow remote administration via SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# --- HTTP / HTTPS (ports 80, 443) ---
# Allow web traffic (Nginx/Apache/Caddy reverse proxy)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# --- PostgreSQL (port 5432) ---
# Allow external access to the database as required by the project
iptables -A INPUT -p tcp --dport 5432 -j ACCEPT

# --- FTP control (port 21) ---
# Allow vsftpd control connection
iptables -A INPUT -p tcp --dport 21 -j ACCEPT

# --- FTP passive data ports (30000-31000) ---
# Allow vsftpd passive mode data connections
iptables -A INPUT -p tcp --dport 30000:31000 -j ACCEPT

# --- ICMP (ping) ---
# Allow ping for network diagnostics
iptables -A INPUT -p icmp -j ACCEPT
