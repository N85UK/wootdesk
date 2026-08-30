# WootDesk Brand and App Icon

Status: Implemented for development, pending final release and trademark review

Last reviewed: 30 August 2026

## Product identity

WootDesk is an independent native client for Chatwoot. Its visual identity must
remain distinct from Chatwoot and must not use Chatwoot's logo, icon, product
screens, or trade dress.

The app icon uses a generic inbox tray and generic conversation panel. The
symbol communicates support work without reproducing another product's mark.

## App icon files

The source assets live in
`WootDesk/Resources/Assets.xcassets/AppIcon.appiconset/`.

| Platform | Master | Treatment |
|---|---|---|
| iOS and iPadOS | `AppIcon-iOS-1024.png` | Opaque, full-bleed square. The system applies the platform mask. |
| macOS | `AppIcon-macOS-512@2x.png` | Transparent outer padding around a rounded-square icon body. |

The macOS catalogue also contains explicit 16, 32, 64, 128, 256, 512, and
1024 pixel files. These are derived from the macOS master because Apple requires
an image for each macOS size. iOS and iPadOS derive their sizes from the single
1024 pixel master.

## Visual rules

- Keep the deep navy, cobalt, cyan, white, and pale grey palette.
- Keep one generic inbox, one generic conversation panel, and one restrained
  sparkle.
- Preserve a strong silhouette and clear contrast at 16 pixels.
- Do not add words, initials, badges, partner logos, or screenshots.
- Do not bake rounded outer corners into the iOS master.
- Do not add opaque black pixels outside the macOS rounded-square body.
- Do not recolour or reshape the Chatwoot logo for WootDesk use.

## Provenance

The maintainer supplied a square visual reference showing a generic inbox and
conversation concept. The final platform masters were newly rendered with the
built-in image-generation workflow on 30 August 2026, then inspected and sized
locally for the Xcode asset catalogue. The supplied reference file is not
committed.

The iOS generation brief was:

> Create a production iOS and iPadOS app icon for WootDesk using a generic inbox
> tray, a generic conversation panel with three status dots and abstract message
> lines, one restrained cyan sparkle, and a deep navy, cobalt, cyan, white, and
> pale grey palette. Use a square opaque full-bleed background with no baked-in
> outer mask. Include no text, watermark, transparency, Chatwoot logo, Chatwoot
> brand mark, or copied product icon.

The macOS edit brief was:

> Preserve the approved WootDesk symbol and palette, but place the design on a
> centred rounded-square backing with transparent outer padding. Keep clean
> antialiased edges and include no opaque corner wedges, text, watermark,
> Chatwoot logo, brand mark, or new object.

## Release checks

Before each release:

1. Run `plutil -lint` on `Contents.json`.
2. Confirm the iOS master is exactly 1024 by 1024 pixels and has no alpha.
3. Confirm the macOS 1024 pixel file has alpha and every named slot matches its
   declared dimensions.
4. Build both destinations and inspect asset-catalog warnings.
5. Inspect the icon on a physical iPhone or iPad, the iOS Simulator, Finder, the
   Dock, and the macOS app switcher.
6. Complete a final trademark and asset-rights review before App Store upload.

The repository licence does not replace the maintainer's responsibility to
confirm the release rights for branding and marketing assets.
