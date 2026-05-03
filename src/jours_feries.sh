#!/usr/bin/env bash
set -euo pipefail

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Erreur : '$cmd' manquant." >&2; exit 1; }
done

YEAR=$(date +%Y)
TODAY=$(date +%Y-%m-%d)
URL="https://calendrier.api.gouv.fr/jours-feries/metropole/${YEAR}.json"

DATA=$(curl -s "$URL")

if [ -z "$DATA" ] || ! echo "$DATA" | jq -e 'type == "object"' > /dev/null 2>&1; then
  echo "Erreur API jours fériés." >&2
  exit 1
fi

NEXT_DAY=$(echo "$DATA" | jq -r 'to_entries[] | .key' | sort | while read -r date; do
  if [[ "$date" > "$TODAY" ]]; then
    echo "$date"
    break
  fi
done)

if [ -n "$NEXT_DAY" ]; then
  NAME=$(echo "$DATA" | jq -r ".\"${NEXT_DAY}\"")
  echo "Prochain jour férié : ${NEXT_DAY} (${NAME})"
else
  echo "Aucun jour férié trouvé pour ${YEAR}."
fi
