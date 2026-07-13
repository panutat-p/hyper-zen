# Apple App Icon Design

## Summary

Apple's current layered app-icon system has been reviewed, but HyperZen will
retain its existing icon design and raster asset pipeline. The Liquid Glass
adaptation changed the character and was rejected after visual review.

The monkey head, including its ears, occupies **70% of the square canvas width**.
It is centered horizontally and kept optically centered vertically.

**Decision:** Do not introduce an Icon Composer `.icon` document or alter the
launcher icon's masking, shadow, colors, proportions, or facial treatment unless
a future design change is explicitly requested.

## Current Design Requirements

- Recognizable as HyperZen at launcher, Dock, Spotlight, and Settings sizes.
- Friendly, minimal, and round rather than detailed or realistic.
- Legible at small sizes with bold shapes and crisp edges.
- Consistent with the existing menu-bar monkey without including its body,
  hands, or legs.
- Preserve the approved brown rounded tile, white head, dark-brown face details,
  existing shadow, and existing proportions exactly.

## Apple Guidance Reviewed (Not Adopted)

Apple's current guidance for iOS, iPadOS, and macOS app icons is based on square,
unmasked artwork composed from a background and one or more foreground layers.
The operating system supplies the final rounded mask and can add highlights,
refraction, translucency, shadows, and depth.

Therefore, production source artwork must:

- Use a square **1024 × 1024** canvas.
- Remain unmasked; do not draw or export rounded corners.
- Keep important content centered so system masking cannot truncate it.
- Use simple, opaque source shapes with crisp boundaries.
- Avoid baked drop shadows, blur, gloss, reflections, translucency, and other
  lighting effects that the system should render.
- Prefer SVG source layers when the artwork can be represented as vectors.
- Preserve the same core identity in every appearance instead of replacing the
  monkey with different artwork.

## Potential Layered Composition (Deferred)

### Geometry

| Element | Requirement |
|---|---|
| Canvas | 1024 × 1024, square and unmasked |
| Complete monkey width | 70% of canvas, including ears |
| Horizontal position | Centered |
| Vertical position | Optically centered; a slight upward offset is allowed |
| Outer margin | 15% minimum on the left and right |
| Corners | No corner shape in source artwork |

The 70% measurement applies to the complete visible silhouette from the outer
edge of the left ear to the outer edge of the right ear. It does not mean that
the central circular face alone is 70%; that interpretation would push the ears
outside the usable canvas.

### Layer Structure

Use no more than four Icon Composer groups:

1. **Background** — solid brown or a restrained brown gradient defined in Icon
   Composer.
2. **Head** — opaque white monkey-head silhouette, including both outer ears.
3. **Face details** — dark-brown eyes, inner ears, and muzzle.
4. **Nose detail** — optional white nose mark; merge it with face details if a
   separate group adds no useful depth.

The layer order should create subtle depth without turning the face into a
detailed illustration. The head silhouette is the primary visual element.

### Shape Language

- Use round ears, round eyes, and a rounded muzzle.
- Use bold forms that survive reduction to 16 points.
- Avoid thin outlines, sharp corners, fur texture, and small decorative marks.
- Keep facial features symmetrical unless a deliberate optical correction is
  necessary.
- Do not add a torso, arms, hands, or legs to the launcher icon.

### Color

- Background: warm medium-to-dark brown.
- Head: white or near-white.
- Facial details: dark brown with sufficient contrast against the head.
- Avoid relying on very subtle tonal differences for recognition.

Exact color values may be tuned in Icon Composer because Liquid Glass effects
and different appearances change perceived contrast.

## Appearance Variants

The icon must be reviewed in the appearances supported by Icon Composer:

- Default
- Dark
- Clear light and clear dark
- Tinted light and tinted dark
- Monochrome, where applicable

Each appearance must retain the monkey-head silhouette and readable facial
features. Variants may adjust color and contrast, but must not change the core
symbol.

## Deferred Apple Pipeline Reference

### Preferred Apple Pipeline

1. Export flat, transparent SVG files for the foreground layers.
2. Assemble the background and layers in Icon Composer.
3. Preview all appearances and representative icon sizes.
4. Save the result as one multilayer `.icon` document.
5. Add the `.icon` document to the Xcode project for modern Apple-platform
   builds.

### Compatibility Pipeline

HyperZen also supports a command-line build on computers without full Xcode.
Until that path can consume the modern `.icon` format, retain generated PNG and
ICNS assets as compatibility fallbacks for older macOS versions and local
`swiftc` app bundles.

The fallback renderer must visually match the layered source. Its rounded tile
and baked shadow are compatibility output only; they must not be included in
the Icon Composer source layers.

## Current Implementation

`Hyperzen/IconRenderer.swift` renders the approved static icon with the complete
monkey width at 70% of the canvas. Xcode uses the committed PNG sizes in
`Hyperzen/Assets.xcassets/AppIcon.appiconset`; command-line builds generate an
ICNS file from the same renderer.

The Apple guidance below remains research for a possible future migration. It
is not an implementation requirement under the current design decision.

## Future Migration Acceptance Criteria (Inactive)

These criteria apply only if a future request explicitly reauthorizes an Icon
Composer migration. They do not apply to the current approved static icon.

- The icon contains a monkey head only.
- The complete head, including ears, is 70% of the canvas width.
- The source layers are square, centered, and unmasked.
- No shadow, highlight, blur, translucency, or rounded-corner mask is baked into
  the modern source artwork.
- Default, dark, clear, tinted, and monochrome previews remain recognizable.
- Eyes, ears, muzzle, and nose remain legible at 16-point preview size.
- Modern `.icon` and compatibility PNG/ICNS outputs depict the same character.
- The icon is inspected in the Dock and launcher before release.

## Apple References

- [App icons — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
- [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer)
- [Icon Composer](https://developer.apple.com/icon-composer/)
- [Liquid Glass overview](https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass)
- [WWDC25: Create icons with Icon Composer](https://developer.apple.com/videos/play/wwdc2025/361/)
- [WWDC25: Say hello to the new look of app icons](https://developer.apple.com/videos/play/wwdc2025/220/)
