# Fullscreen native template

`NativeAdWidget.fullScreen()` is a bundled native ad layout for Android and
iOS. It follows the supplied media-overlay design: media fills the placement,
Ad badge and AdChoices sit at the top, and icon, headline, optional two-line
body, optional SDK star rating and CTA sit at the bottom. It defaults to black
background, white text and a white CTA with a 10dp/pt corner radius. Pass
`NativeAdStyle.fullScreen(...)` to change background, headline/body, CTA/text
colors and CTA radius. The same height is reserved while loading.

The widget uses the available bounded height by default; `height:` can request
a specific height of at least 280 logical pixels. Put the app's close control
outside the ad view and keep AdChoices and CTA unobstructed. The example opens
it on a separate page with an AppBar back button.

After initialization and consent, the library warms one default fullscreen
native ad if a native unit ID exists. A mounted widget claims that ad
exclusively; after handoff, the library prepares one replacement. Custom styles
and ad-unit overrides load on first use. Entitlement, consent and config changes
invalidate pending preloads and visible widgets. The SDK owns impression and
click callbacks; loading alone is not counted as an impression.

Verification checklist:

- Android and iOS example builds compile with the factory registered.
- Dart tests check default/custom colors, factory selection, bounded height,
  preload and lifecycle behavior.
- On real Android and iOS devices, check video and image creatives, close and
  AdChoices clearance, CTA tracking, tall text, landscape and accessibility.

The iPhone 17 Pro simulator rendered Google's Flood-It native test creative.
The Android emulator and iPhone 17 Pro simulator rendered Google's Flood-It
native test creative. The icon, headline, body, rating directly below the body,
and CTA grouped at the bottom on both platforms. Real-device creative rendering
and production impression/show metrics remain unverified until a device and
test/production traffic are available.
