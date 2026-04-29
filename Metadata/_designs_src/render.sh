#!/usr/bin/env bash
set -euo pipefail

# Render Freshli App Store assets via Chrome headless.
# Outputs pixel-perfect PNGs at exact App Store / Apple In-App Events dimensions.

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SRC="/Users/jaysmacbook/Desktop/Freshli/Freshli/Metadata/_designs_src"
ROOT="/Users/jaysmacbook/Desktop/Freshli/Freshli/Metadata"

# Format: input.html  output.png  width  height
RENDERS=(
  # In-App Event cards (1080x1080 — square thumbnails, kept for reference)
  "event_card_plastic_free_july.html|InAppEvents/plastic_free_july/designs/event_card_1080.png|1080|1080"
  "event_card_world_food_day.html|InAppEvents/world_food_day/designs/event_card_1080.png|1080|1080"
  "event_card_holiday_pantry_hero.html|InAppEvents/holiday_pantry_hero/designs/event_card_1080.png|1080|1080"

  # In-App Event cards 16:9 (1920x1080 — ASC required dimensions)
  "event_card_plastic_free_july_1920.html|InAppEvents/plastic_free_july/designs/event_card_1920x1080.png|1920|1080"
  "event_card_world_food_day_1920.html|InAppEvents/world_food_day/designs/event_card_1920x1080.png|1920|1080"
  "event_card_holiday_pantry_hero_1920.html|InAppEvents/holiday_pantry_hero/designs/event_card_1920x1080.png|1920|1080"

  # In-App Event detail pages (1920x1080)
  "event_detail_plastic_free_july.html|InAppEvents/plastic_free_july/designs/event_detail_1920x1080.png|1920|1080"
  "event_detail_world_food_day.html|InAppEvents/world_food_day/designs/event_detail_1920x1080.png|1920|1080"
  "event_detail_holiday_pantry_hero.html|InAppEvents/holiday_pantry_hero/designs/event_detail_1920x1080.png|1920|1080"

  # Custom Product Page hero screenshots (1290x2796 — iPhone 6.9")
  "screenshot_family_focus.html|CustomProductPages/family_focus/designs/iphone69_screenshot_1.png|1290|2796"
  "screenshot_eco_impact.html|CustomProductPages/eco_impact/designs/iphone69_screenshot_1.png|1290|2796"
  "screenshot_ai_chef.html|CustomProductPages/ai_chef/designs/iphone69_screenshot_1.png|1290|2796"
)

render() {
  local input="$1" output="$2" w="$3" h="$4"
  local out_full="$ROOT/$output"
  mkdir -p "$(dirname "$out_full")"
  echo "→ Rendering $input  (${w}×${h})"
  "$CHROME" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --hide-scrollbars \
    --force-device-scale-factor=1 \
    --window-size="$w,$h" \
    --screenshot="$out_full" \
    --default-background-color=00000000 \
    --virtual-time-budget=2000 \
    "file://$SRC/$input" 2>&1 | grep -v -E "^(\[|DevTools|libva|Fontconfig)" || true
}

# Render all in sequence (Chrome can't run multiple headless instances simultaneously easily)
for entry in "${RENDERS[@]}"; do
  IFS='|' read -r input output w h <<< "$entry"
  render "$input" "$output" "$w" "$h"
done

echo ""
echo "✓ All renders complete."
ls -la "$ROOT/InAppEvents"/*/designs/*.png "$ROOT/CustomProductPages"/*/designs/*.png 2>/dev/null
