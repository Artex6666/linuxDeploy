#!/usr/bin/env bash
set -euo pipefail

############################################
# setup_zsh.sh
# - Installe zsh
# - Installe Oh My Zsh pour modo (non interactif)
# - Installe le thème Haribo
# - Définit zsh comme shell par défaut de modo
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

ZSH_USER="${SYSTEM_USER}"
ZSH_HOME="/home/${ZSH_USER}"
OMZ_DIR="${ZSH_HOME}/.oh-my-zsh"
ZSHRC="${ZSH_HOME}/.zshrc"
THEMES_DIR="${OMZ_DIR}/themes"
HARIBO_URL="https://raw.githubusercontent.com/nicoulaj/haribo-zsh-theme/master/haribo.zsh-theme"

log() {
  echo "[INFO] $*"
}

############################################
# 1. Installation de zsh + curl
############################################

install_zsh() {
  log "Installation de zsh et curl..."
  apt-get update -y
  apt-get install -y zsh curl
}

############################################
# 2. Installation de Oh My Zsh (non interactif)
############################################

install_ohmyzsh() {
  if [ -d "${OMZ_DIR}" ]; then
    log "Oh My Zsh déjà installé, on continue."
    return
  fi

  log "Installation de Oh My Zsh pour ${ZSH_USER}..."

  # RUNZSH=no  → ne pas lancer zsh après install
  # CHSH=no    → ne pas changer le shell automatiquement (on le fait manuellement)
  sudo -u "${ZSH_USER}" env \
    RUNZSH=no \
    CHSH=no \
    ZSH="${OMZ_DIR}" \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended

  log "Oh My Zsh installé dans ${OMZ_DIR}."
}

############################################
# 3. Installation du thème Haribo
############################################

install_haribo_theme() {
  log "Installation du thème Haribo..."

  mkdir -p "${THEMES_DIR}"

  curl -fsSL "${HARIBO_URL}" -o "${THEMES_DIR}/haribo.zsh-theme"
  chown "${ZSH_USER}:${ZSH_USER}" "${THEMES_DIR}/haribo.zsh-theme"

  log "Thème Haribo installé dans ${THEMES_DIR}."
}

############################################
# 4. Configuration du .zshrc
############################################

configure_zshrc() {
  log "Configuration du .zshrc (thème Haribo)..."

  # Remplacer le thème par défaut (robbyrussell) par haribo
  if [ -f "${ZSHRC}" ]; then
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="haribo"/' "${ZSHRC}"
  else
    # Créer un .zshrc minimal si absent
    cat > "${ZSHRC}" <<EOF
export ZSH="${OMZ_DIR}"
ZSH_THEME="haribo"
plugins=(git)
source \$ZSH/oh-my-zsh.sh
EOF
  fi

  chown "${ZSH_USER}:${ZSH_USER}" "${ZSHRC}"
  log ".zshrc configuré avec le thème Haribo."
}

############################################
# 5. Définir zsh comme shell par défaut
############################################

set_default_shell() {
  log "Définition de zsh comme shell par défaut pour ${ZSH_USER}..."

  ZSH_PATH="$(which zsh)"

  # Ajouter zsh à /etc/shells si absent
  if ! grep -qx "${ZSH_PATH}" /etc/shells; then
    echo "${ZSH_PATH}" >> /etc/shells
    log "${ZSH_PATH} ajouté à /etc/shells."
  fi

  chsh -s "${ZSH_PATH}" "${ZSH_USER}"
  log "Shell par défaut de ${ZSH_USER} : ${ZSH_PATH}"
}

############################################
# Main
############################################

main() {
  install_zsh
  install_ohmyzsh
  install_haribo_theme
  configure_zshrc
  set_default_shell
  log "setup_zsh.sh terminé."
}

main "$@"
