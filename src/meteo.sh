#!/usr/bin/env bash
set -euo pipefail

############################################
# meteo.sh — Météo du jour via OpenWeatherMap
# Écrit le résultat dans /etc/motd
# Lancé par cron tous les jours à 06h00
############################################

API_KEY="601bf28939ed5b5d2473a2169608ff12"
CITY="Paris"

# Vérification des dépendances
for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Erreur : '$cmd' n'est pas installé." >&2
    exit 1
  fi
done

# Appel API OpenWeatherMap
DATA=$(curl -s "https://api.openweathermap.org/data/2.5/weather?q=${CITY}&units=metric&lang=fr&appid=${API_KEY}")

# Vérification réponse API
if ! echo "$DATA" | jq -e '.main.temp' > /dev/null 2>&1; then
  echo "Erreur API météo : réponse inattendue ou clé invalide." >&2
  echo "$DATA" >&2
  exit 1
fi

# Extraction des données (température arrondie à l'entier)
TEMP=$(echo "$DATA" | jq '.main.temp | round')
DESC=$(echo "$DATA" | jq -r '.weather[0].description')

# Écriture dans le message du jour (pas besoin de sudo : script lancé en root par cron)
echo "Météo du jour (${CITY}) : ${TEMP}°C, ${DESC}" > /etc/motd
