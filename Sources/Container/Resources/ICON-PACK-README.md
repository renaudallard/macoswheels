# macoswheels — Icon Pack

Original icon set for a macOS app that manages racing wheels with force feedback (incl. CrossOver/Wine bridging). No trademarked marks; the apple‑fruit watermark on the app icon is a generic fruit silhouette (round body + stem + leaf, no bite).

## Contents

```
pack/
├─ app-icon/
│  ├─ AppIcon-default.svg          # master vector, 1024×1024
│  ├─ AppIcon-dark.svg             # dark-theme background variant
│  ├─ AppIcon-mono.svg             # monochrome variant (greyscale background)
│  ├─ AppIcon-1024.png             # 1024 raster (App Store / marketing)
│  └─ AppIcon.iconset/             # macOS iconset — ready for iconutil
│     ├─ icon_16x16.png
│     ├─ icon_16x16@2x.png
│     ├─ icon_32x32.png
│     ├─ icon_32x32@2x.png
│     ├─ icon_128x128.png
│     ├─ icon_128x128@2x.png
│     ├─ icon_256x256.png
│     ├─ icon_256x256@2x.png
│     ├─ icon_512x512.png
│     └─ icon_512x512@2x.png
├─ menu-bar/
│  ├─ MenuBarTemplate.svg          # NSImage template — set isTemplate = true
│  ├─ MenuBarTemplate.png          # 22px raster
│  └─ MenuBarTemplate@2x.png       # 44px raster
└─ ui-icons/
   ├─ wheel.svg                    # toolbar / sidebar — 24×24, currentColor
   ├─ pedals.svg
   ├─ shifter.svg
   ├─ handbrake.svg
   ├─ force-feedback.svg
   ├─ calibration.svg
   ├─ button-mapping.svg
   ├─ deadzone.svg
   ├─ sensitivity.svg
   ├─ profile.svg
   ├─ games.svg
   ├─ crossover-bridge.svg
   ├─ telemetry.svg
   ├─ diagnostics.svg
   ├─ usb.svg
   ├─ bluetooth.svg
   ├─ settings.svg
   ├─ help.svg
   ├─ add.svg
   ├─ remove.svg
   ├─ test.svg
   ├─ reset.svg
   ├─ import.svg
   ├─ export.svg
   ├─ update.svg
   └─ warning.svg
```

## Build the .icns

```bash
cd app-icon
iconutil -c icns AppIcon.iconset
# → AppIcon.icns
```

Drop `AppIcon.icns` into your Xcode project's Assets.xcassets (or set it as your bundle's `CFBundleIconFile`).

## UI icons (SwiftUI / AppKit)

The 24×24 monoline SVGs use `stroke="currentColor"` so they tint with the surrounding label color.

- **SwiftUI**: drop each SVG into your asset catalog as a Symbol Image (Single Scale, Template Rendering Mode) and use `Image("wheel").renderingMode(.template)`.
- **AppKit**: `NSImage(named: "wheel")?.isTemplate = true`.
- Stroke is 1.75 on a 24-grid; render the SVG at 14 / 18 / 24 / 32 / 44 for toolbar, sidebar, list-row, large-toolbar, and hero placements.

## Menu bar icon

`MenuBarTemplate.svg` is a template image — black on transparent. macOS will invert it automatically for dark menu bars when you set `isTemplate = true`.

## Design tokens

- App icon background: `#070d1e → #1e4a8a` (racing-ink radial)
- Hub accent: `#f29036` (amber)
- Rim metal: `#f3f6fb → #a9b6cc` (cool silver)
- Stroke width (UI icons): 1.75pt on 24-grid, round caps + joins
- App icon squircle radius: macOS standard (`M512 0 C 145.7 0 0 145.7 0 512 ...`)
