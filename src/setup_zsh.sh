#!/usr/bin/env bash
set -euo pipefail

ZSH_USER="modo"
ZSH_HOME="/home/${ZSH_USER}"
OMZ_DIR="${ZSH_HOME}/.oh-my-zsh"
ZSHRC="${ZSH_HOME}/.zshrc"
THEMES_DIR="${OMZ_DIR}/themes"
HARIBO_URL="https://raw.githubusercontent.com/nicoulaj/haribo-zsh-theme/master/haribo.zsh-theme"

log() { echo "[INFO] $*"; }

############################################
# 1. zsh
############################################

install_zsh() {
  apt-get update -y
  apt-get install -y zsh curl
}

############################################
# 2. Oh My Zsh
############################################

install_ohmyzsh() {
  if [ -d "${OMZ_DIR}" ]; then
    log "Oh My Zsh déjà installé."
    return
  fi

  sudo -u "${ZSH_USER}" env RUNZSH=no CHSH=no ZSH="${OMZ_DIR}" \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended || true
}

############################################
# 3. Thème Haribo
############################################

install_haribo() {
  mkdir -p "${THEMES_DIR}"
  curl -fsSL "${HARIBO_URL}" -o "${THEMES_DIR}/haribo.zsh-theme"
  chown "${ZSH_USER}:${ZSH_USER}" "${THEMES_DIR}/haribo.zsh-theme"
}

############################################
# 4. .zshrc
############################################

configure_zshrc() {
  if [ -f "${ZSHRC}" ]; then
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="haribo"/' "${ZSHRC}"
  else
    cat > "${ZSHRC}" <<EOF
export ZSH="${OMZ_DIR}"
ZSH_THEME="haribo"
plugins=(git)
source \$ZSH/oh-my-zsh.sh
EOF
  fi
  chown "${ZSH_USER}:${ZSH_USER}" "${ZSHRC}"
}

############################################
# 5. Shell par défaut
############################################

set_default_shell() {
  ZSH_PATH="$(which zsh)"
  grep -qx "${ZSH_PATH}" /etc/shells || echo "${ZSH_PATH}" >> /etc/shells
  chsh -s "${ZSH_PATH}" "${ZSH_USER}"
  log "Shell de ${ZSH_USER} → zsh."
}

main() {
  install_zsh
  install_ohmyzsh
  install_haribo
  configure_zshrc
  set_default_shell
}

main "$@"
