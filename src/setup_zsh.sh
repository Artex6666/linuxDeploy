#!/usr/bin/env bash
set -euo pipefail

ZSH_USER="modo"
ZSH_HOME="/home/${ZSH_USER}"
OMZ_DIR="${ZSH_HOME}/.oh-my-zsh"
ZSHRC="${ZSH_HOME}/.zshrc"
THEMES_DIR="${OMZ_DIR}/themes"

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
  cat > "${THEMES_DIR}/haribo.zsh-theme" <<'THEME'
local _lineup=$'\e[1A'
local _linedown=$'\e[1B'

PROMPT='%{%f%k%b%}
$(git_prompt_info)$(hg_prompt_info)%{${fg_bold[green]}%}%n%{${fg[default]}%}@%{${fg_bold[green]}%}%m %{${fg_bold[blue]}%}%~ %{${fg[default]}%}
$ %{$reset_color%}'

RPROMPT='%{${_lineup}%}%{${fg_bold[yellow]}%}%D{%H:%M:%S}%{${fg[default]}%}%{${_linedown}%}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{${fg_bold[blue]}%}git:(%{${fg_bold[red]}%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{${fg_bold[blue]}%}) %{${fg_bold[yellow]}%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{${fg_bold[blue]}%})"
THEME
  chown "${ZSH_USER}:${ZSH_USER}" "${THEMES_DIR}/haribo.zsh-theme"
  log "Thème Haribo installé."
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
