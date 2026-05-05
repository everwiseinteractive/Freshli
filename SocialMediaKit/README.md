# Freshli — Social Media Kit for Alderframe

**Welcome, team.** Everything you need to start running Freshli's social media is in this folder.

This kit was generated 29 April 2026 ahead of the Freshli 1.0 launch. The app is currently with App Review (build 23) — once it's approved, the launch sequence in `ContentCalendar.md` kicks off Day 0.

---

## 📁 What's in this folder

```
SocialMediaKit/
├── README.md                       ← you are here
├── BrandGuide.md                   ← voice, tone, palette, do/don'ts (READ FIRST)
├── Captions.md                     ← paste-ready captions per post per platform
├── Hashtags.md                     ← hashtag bundles + trending watchlist
├── ContentCalendar.md              ← 30-day launch plan + recurring cadence
├── PressKit.md                     ← press release, founder bio, talking points
│
├── 01_Logo/                        ← brand mark in SVG + PNG (multiple sizes)
│   ├── freshli_leaf.svg
│   ├── freshli_leaf_{128,256,512,1024}.png
│   ├── freshli_wordmark.svg + .png  (dark logotype on light)
│   └── freshli_wordmark_white.svg + .png  (white logotype on dark)
│
├── 02_Profiles/                    ← avatar at every platform size
│   └── freshli_avatar_{96,200,256,400,512,800,1080}.png
│
├── 03_Banners/                     ← cover images per platform
│   ├── twitter_header_1500x500.png   (X / Twitter)
│   └── linkedin_banner_1584x396.png  (LinkedIn personal & company)
│
├── 04_FeedPosts/                   ← 1080×1080 — Instagram, Facebook, LinkedIn
│   ├── post_01_launch.png            "Rescue food. Save the planet."
│   ├── post_02_ai_chef.png           Apple Intelligence in 0.84s
│   ├── post_03_stat_co2.png          "10% of global emissions"
│   ├── post_04_family_plan.png       Freshli+ Family £5.99/mo
│   ├── post_05_brand_quote.png       Brand manifesto
│   └── post_06_weekly_wrap.png       Weekly Wrap template
│
├── 05_Stories/                     ← 1080×1920 — IG Stories, Facebook Stories
│   ├── story_01_launch.png
│   ├── story_02_ai_chef.png
│   └── story_03_food_waste_stat.png
│
├── 06_Reels/                       ← 1080×1920 — Reels & TikTok video covers
│   └── reel_cover_{01,02,03}*.png
│
└── _src/                           ← HTML/CSS source for every visual asset
    ├── social.css
    ├── render.sh                    re-renders all PNGs in one command
    └── *.html                       one file per design
```

---

## 🚀 Quick-start checklist for the Alderframe team

### Day -7 (one week before launch)

- [ ] Read `BrandGuide.md` cover-to-cover (~10 min)
- [ ] Set up Freshli accounts on each platform (handles requested: `@freshli` everywhere — exact availability TBC)
- [ ] Upload `02_Profiles/freshli_avatar_400.png` as the avatar on every platform
- [ ] Upload `03_Banners/twitter_header_1500x500.png` to X
- [ ] Upload `03_Banners/linkedin_banner_1584x396.png` to LinkedIn (both personal Jay account and Freshli company page)
- [ ] Set bios to the templates in `Captions.md` § "Bio templates"
- [ ] Pin the launch post template (`post_01_launch.png`) in drafts on every platform

### Day -3

- [ ] Schedule Day 0 launch post on every platform (use Buffer / Hootsuite / native scheduling)
- [ ] Schedule Days 1–3 follow-up posts
- [ ] Notify any seed accounts (10–15 friends-of-Jay willing to engage on launch day) — prep DM template

### Day 0 (LAUNCH)

- [ ] First post goes live at **8 AM BST** on all platforms simultaneously
- [ ] Post `story_01_launch.png` on IG/FB Stories with link sticker → App Store
- [ ] Reply to every comment within 60 minutes for the first 4 hours
- [ ] Monitor for press pickup — DM Jay with anything tier-2+

### Days 1–30

- [ ] Follow `ContentCalendar.md` Week-by-Week breakdown
- [ ] Publish at consistent times (post: 8 AM / story: 12 PM / reel: 6 PM BST — adjust per analytics after week 1)
- [ ] Reshare every UGC post that tags `@freshli` or uses `#FreshliApp`
- [ ] Send Jay a Friday recap each week with: top post, top story, follower deltas, app download attribution

---

## 🎯 The 3 things that actually matter

If you do nothing else, do these:

1. **Be on-brand.** Read `BrandGuide.md`. The voice rules and the 3 core stories are the brain of the operation. If a post doesn't fit one of the 3 stories, it's probably wrong.

2. **Post the launch sequence with no gaps.** Days 0, 1, 2, 3, and 5 are critical. Even if other days slip, those 5 cannot. They establish the brand category in the algorithm.

3. **Reply, don't broadcast.** First-month engagement is more valuable than first-month follower growth. Every reply within 60 minutes compounds.

---

## 🛠️ Re-rendering or editing assets

If you need to change a design (e.g. swap a stat, update the price, refresh for a new event):

```bash
# Edit the source HTML in _src/, then:
cd /Users/jaysmacbook/Desktop/Freshli/Freshli/SocialMediaKit
bash _src/render.sh
```

This rebuilds every PNG from its HTML source via Chrome headless. Each design is a separate `_src/*.html` file with inline SVG and standard CSS — no build step, no Figma, no dependencies. Edit in any text editor.

---

## 🔗 Cross-links to other Freshli assets

The Social Media Kit lives alongside two other asset folders the team may need:

- **`/Metadata/CustomProductPages/`** — App Store custom product page screenshots (Family Focus, Eco Impact, AI Chef) at 1242×2688. These are app screenshots, ideal for IG carousels and feature posts.
- **`/Metadata/InAppEvents/`** — In-App Event card images for Plastic Free July (Jul 2026), World Food Day (Oct 16 2026), and Holiday Pantry Hero (Dec 18–31 2026). Repurpose for social on those dates — already coordinated.

Both of those folders have their own `STORE_ASSETS_README.md` with full details.

---

## 📞 Contact & ownership

| Role | Person | Contact |
|------|--------|---------|
| **Founder / final brand approval** | Jay Lawrence | support@freshli.app |
| **Social media management** | Alderframe team | (your channel) |
| **Press inquiries** | Jay Lawrence (cc Alderframe) | support@freshli.app |
| **Technical / app questions** | Jay Lawrence | support@freshli.app |

For brand-tone disagreements: Alderframe makes the call on tactical decisions (which hashtag, which crop). Jay makes the call on anything strategic (new positioning, partnership posts, anything that breaks the 3-stories framework).

---

## 🌱 The point

Freshli is a real app trying to solve a real climate problem with a serious technical bet on on-device AI. The social media should match that energy: confident, useful, evidenced, human.

Don't make it sound like a startup. Make it sound like a lighthouse.

*For the people. For the planet.*

— Jay
