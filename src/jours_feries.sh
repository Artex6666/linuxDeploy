#!/usr/bin/env bash
set -euo pipefail

############################################
# jours_feries.sh — Prochain jour férié FR
# Utilise l'API officielle data.gouv.fr
# Usage : ./jours_feries.sh
############################################

# Vérification des dépendances
for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Erreur : '$cmd' n'est pas installé." >&2
    exit 1
  fi
done

YEAR=$(date +%Y)
TODAY=$(date +%Y-%m-%d)
URL="https://calendrier.api.gouv.fr/jours-feries/metropole/${YEAR}.json"

# Appel API
DATA=$(curl -s "$URL")

# Vérification réponse API (doit être un objet JSON non vide)
if [ -z "$DATA" ] || ! echo "$DATA" | jq -e 'type == "object"' > /dev/null 2>&1; then
  echo "Erreur lors de l'appel à l'API des jours fériés." >&2
  exit 1
fi

# Recherche du prochain jour férié strictement après aujourd'hui
# (si aujourd'hui est férié, on retourne le suivant — même logique)
NEXT_DAY=$(echo "$DATA" | jq -r 'to_entries[] | .key' | sort | while read -r date; do
  if [[ "$date" > "$TODAY" ]]; then
    echo "$date"
    break
  fi
done)

# Affichage du résultat
if [ -n "$NEXT_DAY" ]; then
  NAME=$(echo "$DATA" | jq -r ".\"${NEXT_DAY}\"")
  echo "Prochain jour férié : ${NEXT_DAY} (${NAME})"
else
  echo "Aucun jour férié trouvé pour le reste de l'année ${YEAR}."
fi
