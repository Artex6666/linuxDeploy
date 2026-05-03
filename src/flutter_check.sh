#!/usr/bin/env bash

FLUTTER_SDK="/opt/flutter"
LOG_FILE="/var/log/flutter-integrity.log"
DISCORD_WEBHOOK="__DISCORD_WEBHOOK__"

# Écrase le log à chaque vérification
> "${LOG_FILE}"

echo "=== Flutter integrity check — $(date '+%Y-%m-%d %H:%M:%S') ===" >> "${LOG_FILE}"

# Vérification du dossier SDK
if [ ! -d "${FLUTTER_SDK}" ]; then
  echo "[FAIL] SDK Flutter introuvable : ${FLUTTER_SDK}" >> "${LOG_FILE}"
  exit 1
fi

echo "[OK] SDK Flutter présent : ${FLUTTER_SDK}" >> "${LOG_FILE}"

# Vérification flutter doctor
DOCTOR_OUTPUT=$("${FLUTTER_SDK}/bin/flutter" doctor 2>&1)

if echo "${DOCTOR_OUTPUT}" | grep -q "\[✓\]\|No issues found"; then
  echo "[OK] flutter doctor : aucun problème détecté" >> "${LOG_FILE}"
else
  echo "[WARN] flutter doctor a détecté des problèmes :" >> "${LOG_FILE}"
  echo "${DOCTOR_OUTPUT}" | grep -v "^\s*$" >> "${LOG_FILE}"
fi

# Notification Discord
SUMMARY=$(cat "${LOG_FILE}")
MESSAGE="$(printf '**Flutter integrity check**\n```\n%s\n```' "${SUMMARY}")"
curl -s -X POST "${DISCORD_WEBHOOK}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg content "${MESSAGE}" '{content: $content}')"
