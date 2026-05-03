#!/usr/bin/env bash
set -euo pipefail

API_KEY="601bf28939ed5b5d2473a2169608ff12"
CITY="Paris"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Erreur : '$cmd' manquant." >&2; exit 1; }
done

DATA=$(curl -s "https://api.openweathermap.org/data/2.5/weather?q=${CITY}&units=metric&lang=fr&appid=${API_KEY}")

if ! echo "$DATA" | jq -e '.main.temp' > /dev/null 2>&1; then
  echo "Erreur API météo." >&2
  echo "$DATA" >&2
  exit 1
fi

TEMP=$(echo "$DATA" | jq '.main.temp | round')
DESC=$(echo "$DATA" | jq -r '.weather[0].description')

echo "Météo du jour (${CITY}) : ${TEMP}°C, ${DESC}" > /etc/motd
