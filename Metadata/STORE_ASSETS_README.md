# Freshli — App Store Connect Asset Index

This folder contains complete metadata + designs for **3 In-App Events** and **3 Custom Product Pages**, all production-ready for paste-into App Store Connect.

Generated 29 April 2026 · Freshli 1.0 · build 23.

---

## 📁 Structure

```
Metadata/
├── InAppEvents/
│   ├── plastic_free_july/
│   │   ├── metadata.json              ← canonical source of truth
│   │   ├── translations/              ← paste-ready .txt per locale
│   │   │   ├── en-GB.txt              ← Event Name + Short + Long + Notification
│   │   │   ├── es.txt
│   │   │   ├── fr.txt
│   │   │   ├── de.txt
│   │   │   ├── pt-BR.txt
│   │   │   └── ja.txt
│   │   └── designs/
│   │       ├── event_card_1080.png        (1080 × 1080 — ASC: Event Card)
│   │       └── event_detail_1920x1080.png (1920 × 1080 — ASC: Event Details Image)
│   ├── world_food_day/
│   └── holiday_pantry_hero/
│
└── CustomProductPages/
    ├── family_focus/
    │   ├── metadata.json
    │   ├── translations/                ← Promotional Text + Description
    │   │   ├── en-GB.txt
    │   │   ├── es.txt … ja.txt
    │   └── designs/
    │       └── iphone69_screenshot_1.png (1290 × 2796 — ASC: Screenshot 1)
    ├── eco_impact/
    └── ai_chef/
```

> **Source HTML/CSS** for every design lives in `Metadata/_designs_src/` — re-render at any time with `bash _designs_src/render.sh`.

---

## 🟢 In-App Events — 3 ready to submit

| # | Event | Badge | Window | Asset folder |
|---|-------|-------|--------|--------------|
| 1 | **Plastic Free July** | Challenge | Jul 1–31 2026 | `InAppEvents/plastic_free_july/` |
| 2 | **World Food Day Sprint** | Special Event | Oct 16 2026 (1-day) | `InAppEvents/world_food_day/` |
| 3 | **Holiday Pantry Hero** | Challenge · 2× Karma | Dec 18–31 2026 | `InAppEvents/holiday_pantry_hero/` |

### How to submit each in App Store Connect

1. **Distribution → In-App Events → Create New Event**
2. **Reference Name** ← `metadata.json` → `referenceName`
3. **Event Badge** ← `metadata.json` → `badge`
4. **Schedule** → set Time Zone to *Europe/London*; copy `eventStart` / `eventEnd` from `schedule`
5. **Deep Link URL** ← `deepLinkURL` (already wired up in app — `URLRouterService` handles `/events/*`)
6. **Primary Locale** ← English (UK)
7. **Add Localizations** → for each of the 6 locales:
   - Open `translations/{locale}.txt`
   - Paste **Event Name**, **Short Description**, **Long Description**, **Notification Text**
8. **Event Card** → upload `designs/event_card_1080.png`
9. **Event Details Page** → upload `designs/event_detail_1920x1080.png`
10. **Submit for review**

> Apple recommends submitting In-App Events at least **8 days** before the publish date. The schedule in each `metadata.json` already accounts for this.

---

## 🟣 Custom Product Pages — 3 ready to submit

| # | Page | Audience | Drives | Asset folder |
|---|------|----------|--------|--------------|
| 1 | **Family Focus** | Parents, families | Freshli+ Family £5.99/mo | `CustomProductPages/family_focus/` |
| 2 | **Eco Impact** | Climate-conscious, Gen Z eco-warriors | Freshli+ Pro £3.99/mo | `CustomProductPages/eco_impact/` |
| 3 | **AI Chef** | Tech-savvy, Apple Intelligence early adopters | Freshli+ Pro £3.99/mo | `CustomProductPages/ai_chef/` |

### How to submit each in App Store Connect

1. **Distribution → Custom Product Pages → Create New Page**
2. **Reference Name** ← `metadata.json` → `referenceName`
3. **URL Slug** ← `metadata.json` → `url`  *(this becomes the `?ppid=` parameter on App Store links)*
4. **For each of the 6 locales** (English UK is primary):
   - Open `translations/{locale}.txt`
   - Paste **Promotional Text** (max 170 chars)
   - Paste **Description** (max 4000 chars)
5. **Screenshots** → upload `designs/iphone69_screenshot_1.png` as **iPhone 6.9"** screenshot 1 (Apple will auto-generate 6.5" by scaling).
   - Slots 2–10 may reuse the default app screenshots — Custom Product Pages only require the *first* screenshot to differ.
6. **App Preview Video** → optional (the default video applies if none uploaded).
7. **Save & Submit for review** (independent of app version review).

After approval, the **Marketing URL** for each page is:
```
https://apps.apple.com/gb/app/freshli/idXXXXXXXXX?ppid=<url>
e.g. https://apps.apple.com/gb/app/freshli/idXXXXXXXXX?ppid=freshli-family
```
Use this URL in family-targeted ads / climate-blog placements / Apple Intelligence demos respectively.

---

## 🌍 Locales covered

All copy is localised across **6 markets** matching the app's `Localizable.xcstrings`:

| Locale | Market | Strategic value |
|--------|--------|----------------|
| **en-GB** | UK / Ireland / Australia | Primary — Apple's English markets |
| **es** | Spain + Latin America | 2nd-largest App Store market |
| **fr** | France / Canada / Africa | Climate-conscious markets |
| **de** | DACH (Germany / Austria / Switzerland) | Premium subscription markets |
| **pt-BR** | Brazil | Massive growth market |
| **ja** | Japan | High ARPU, Apple's favourite showcase |

---

## 🎨 Design notes

All designs follow **Freshli's Liquid Glass design language** as defined in `CLAUDE.md`:

- **Mesh gradients** rendered with multi-stop radial gradients
- **Glass-card** surfaces with `backdrop-filter: blur(40px) saturate(180%)`
- **Specular highlights** via `linear-gradient(135deg, rgba(255,255,255,0.4) 0%, transparent 40%)`
- **Brand greens** sourced from Tailwind palette (#22C55E, #16A34A, #15803D)
- **Accent palette** matches in-app `FLColors.swift` (amber #F59E0B, teal #14B8A6, rose for festive)

### Design philosophy per asset

| Asset | Primary visual | Mood | Accent |
|-------|---------------|------|--------|
| Plastic Free July card | Glass jar with food + "PLASTIC FREE" label | Cool, clean, summery | Teal |
| World Food Day card | Globe with live rescue pins + arrows | Urgent, global, energetic | Amber |
| Holiday Pantry Hero card | Wreath of food + gift box | Warm, festive, generous | Rose + green |
| Family Focus screenshot | Two phones side-by-side showing synced pantry | Connected, warm, lived-in | Amber CTA |
| Eco Impact screenshot | Phone showing CO₂ dashboard with science-backed comparisons | Authoritative, scientific, hopeful | Teal |
| AI Chef screenshot | Phone showing Rescue Chef generating 3 recipes in 0.84s | Premium, futuristic, private | Apple Intelligence gradient (amber→teal→purple) |

---

## 🔁 Re-rendering

To rebuild any design after editing the source HTML:

```bash
cd /Users/jaysmacbook/Desktop/Freshli/Freshli/Metadata
bash _designs_src/render.sh
```

To rebuild only the translation .txt files after editing `metadata.json`:

```bash
bash _designs_src/split_translations.sh
```

Both scripts are idempotent — safe to run repeatedly.

---

## ✅ Checklist before submission

- [ ] All 6 locales pasted into ASC for **each** event (3 × 6 = 18 paste actions)
- [ ] All 6 locales pasted into ASC for **each** custom page (3 × 6 = 18 paste actions)
- [ ] 3 event card PNGs uploaded (1080×1080 each)
- [ ] 3 event detail PNGs uploaded (1920×1080 each)
- [ ] 3 custom-page hero screenshots uploaded (1290×2796 each)
- [ ] Deep links verified in app (`URLRouterService` handles `freshli://events/*` and `freshli://upgrade/family`)
- [ ] Schedule windows confirmed against current quarter
- [ ] Each event's **publish date** is at least 8 days before the **event start**

---

*Built by Jay Lawrence · Freshli · For the people. For the planet.*
