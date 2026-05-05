#!/usr/bin/env bash
set -euo pipefail
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SRC="/Users/jaysmacbook/Desktop/Freshli/Freshli/SocialMediaKit/_src"
ROOT="/Users/jaysmacbook/Desktop/Freshli/Freshli/SocialMediaKit"

# Format: input.html|output.png|width|height
RENDERS=(
  # Profile avatar — used across all platforms (downscale as needed)
  "profile_avatar_1080.html|02_Profiles/freshli_avatar_1080.png|1080|1080"

  # Banners
  "twitter_header.html|03_Banners/twitter_header_1500x500.png|1500|500"
  "linkedin_banner.html|03_Banners/linkedin_banner_1584x396.png|1584|396"

  # Feed posts (1080×1080 — Instagram, Facebook, LinkedIn)
  "post_launch.html|04_FeedPosts/post_01_launch.png|1080|1080"
  "post_ai_chef.html|04_FeedPosts/post_02_ai_chef.png|1080|1080"
  "post_stat_co2.html|04_FeedPosts/post_03_stat_co2.png|1080|1080"
  "post_family.html|04_FeedPosts/post_04_family_plan.png|1080|1080"
  "post_quote.html|04_FeedPosts/post_05_brand_quote.png|1080|1080"
  "post_weekly_wrap.html|04_FeedPosts/post_06_weekly_wrap.png|1080|1080"

  # Stories (1080×1920 — Instagram/Facebook stories, Reels covers, TikTok cover)
  "story_launch.html|05_Stories/story_01_launch.png|1080|1920"
  "story_ai_chef.html|05_Stories/story_02_ai_chef.png|1080|1920"
  "story_stat.html|05_Stories/story_03_food_waste_stat.png|1080|1920"
)

for entry in "${RENDERS[@]}"; do
  IFS='|' read -r input output w h <<< "$entry"
  out="$ROOT/$output"
  mkdir -p "$(dirname "$out")"
  echo "→ $input  (${w}×${h})"
  "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --force-device-scale-factor=1 --window-size="$w,$h" \
    --screenshot="$out" --virtual-time-budget=2000 \
    "file://$SRC/$input" 2>&1 | grep -v -E "^(\[|DevTools|libva|Fontconfig)" | tail -1
done

# Generate cross-platform avatar sizes from the 1080 master
SIPS_OUT="$ROOT/02_Profiles"
for size in 400 200 800 512 256 96; do
  cp "$SIPS_OUT/freshli_avatar_1080.png" "$SIPS_OUT/freshli_avatar_${size}.png"
  sips --resampleHeightWidth $size $size "$SIPS_OUT/freshli_avatar_${size}.png" >/dev/null 2>&1
done

# Reels/TikTok covers reuse story renders (same 9:16 aspect)
mkdir -p "$ROOT/06_Reels"
cp "$ROOT/05_Stories/story_01_launch.png" "$ROOT/06_Reels/reel_cover_01_launch.png"
cp "$ROOT/05_Stories/story_02_ai_chef.png" "$ROOT/06_Reels/reel_cover_02_ai_chef.png"
cp "$ROOT/05_Stories/story_03_food_waste_stat.png" "$ROOT/06_Reels/reel_cover_03_stat.png"

echo ""
echo "✓ All renders complete."
ls "$ROOT/02_Profiles" "$ROOT/03_Banners" "$ROOT/04_FeedPosts" "$ROOT/05_Stories" "$ROOT/06_Reels"
