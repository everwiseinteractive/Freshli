#!/usr/bin/env bash
# Convert metadata.json files into per-language paste-ready .txt files.
# Each .txt file contains the exact field copy for App Store Connect.

set -euo pipefail

ROOT="/Users/jaysmacbook/Desktop/Freshli/Freshli/Metadata"
LOCALES=("en-GB" "es" "fr" "de" "pt-BR" "ja")

# === In-App Events ===
EVENTS=("plastic_free_july" "world_food_day" "holiday_pantry_hero")

for event in "${EVENTS[@]}"; do
  json="$ROOT/InAppEvents/$event/metadata.json"
  out_dir="$ROOT/InAppEvents/$event/translations"
  mkdir -p "$out_dir"

  ref=$(jq -r '.referenceName' "$json")
  badge=$(jq -r '.badge' "$json")
  start=$(jq -r '.schedule.eventStart' "$json")
  end=$(jq -r '.schedule.eventEnd' "$json")
  deeplink=$(jq -r '.deepLinkURL' "$json")

  for loc in "${LOCALES[@]}"; do
    name=$(jq -r ".localizations[\"$loc\"].eventName" "$json")
    short=$(jq -r ".localizations[\"$loc\"].shortDescription" "$json")
    long=$(jq -r ".localizations[\"$loc\"].longDescription" "$json")
    notif=$(jq -r ".localizations[\"$loc\"].notificationText" "$json")

    cat > "$out_dir/$loc.txt" <<EOF
# ASC In-App Event Paste Sheet — $loc
# Event: $ref · Badge: $badge
# Window: $start → $end
# Deep link: $deeplink

──────────────────────────────────────────────
EVENT NAME (max 30 chars):
$name

──────────────────────────────────────────────
SHORT DESCRIPTION (max 50 chars):
$short

──────────────────────────────────────────────
LONG DESCRIPTION (max 120 chars):
$long

──────────────────────────────────────────────
NOTIFICATION TEXT (max 50 chars, optional):
$notif
EOF
    echo "  ✓ events/$event/$loc.txt"
  done
done

# === Custom Product Pages ===
PAGES=("family_focus" "eco_impact" "ai_chef")

for page in "${PAGES[@]}"; do
  json="$ROOT/CustomProductPages/$page/metadata.json"
  out_dir="$ROOT/CustomProductPages/$page/translations"
  mkdir -p "$out_dir"

  ref=$(jq -r '.referenceName' "$json")
  url=$(jq -r '.url' "$json")
  audience=$(jq -r '.audience' "$json")

  for loc in "${LOCALES[@]}"; do
    promo=$(jq -r ".localizations[\"$loc\"].promotionalText" "$json")
    desc=$(jq -r ".localizations[\"$loc\"].description" "$json")

    cat > "$out_dir/$loc.txt" <<EOF
# ASC Custom Product Page Paste Sheet — $loc
# Page: $ref · URL: $url
# Target: $audience

──────────────────────────────────────────────
PROMOTIONAL TEXT (max 170 chars):
$promo

──────────────────────────────────────────────
DESCRIPTION (max 4000 chars):
$desc
EOF
    echo "  ✓ pages/$page/$loc.txt"
  done
done

echo ""
echo "Done. $(find $ROOT/InAppEvents/*/translations $ROOT/CustomProductPages/*/translations -name '*.txt' | wc -l | tr -d ' ') translation files written."
