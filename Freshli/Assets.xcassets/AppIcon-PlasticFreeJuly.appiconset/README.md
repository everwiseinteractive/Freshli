# Alternate App Icon Set — Stub

This `.appiconset` is a **stub** awaiting the rendered PNG art.

## How to populate

1. Run the SwiftUI preview in `Freshli/DesignSystem/DynamicAppIcon/SeasonalIconRenderer.swift`
   for the matching `SeasonalIconRenderer.<Name>Icon` view.
2. In Xcode Preview, click the share button → "Export as Image" → 1024×1024 PNG.
3. Repeat for `appearance: .light`, `.dark`, and `.tinted`.
4. Drop the three PNGs into this folder named:
   - `AppIcon-<Name>-1024.png`              (default / light)
   - `AppIcon-<Name>-1024-dark.png`         (dark appearance)
   - `AppIcon-<Name>-1024-tinted.png`       (iOS 18 tinted home screen)
5. Replace `Contents.json` with the three-image schema (see git history of
   any `appiconset` for the exact JSON shape).
6. The `Info.plist` already references the alternate icon name —
   `AlternateIconService.setIcon(.<name>)` will start working immediately.

Until the PNGs are dropped in, the alternate icon name resolves to nothing
at runtime, and `AlternateIconService.setIcon(_:)` logs a warning but
does not crash.
