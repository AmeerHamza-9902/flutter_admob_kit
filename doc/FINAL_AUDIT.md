# Technical audit

Updated 8 October 2026 for package version 4.0.0. This document records
verified behavior and remaining validation work; it does not predict AdMob
match rate, impressions, CTR, or revenue.

## Current architecture

- `AdMobKit` owns SDK initialization, consent and entitlement gates. Fullscreen
  formats use a shared presentation mutex and independent single-ad caches;
  named placements have their own caches.
- Banner and native preload controllers are internal. The library warms one
  default large banner, `bigNative`, and `mediumNative` after initialization
  when matching unit IDs and consent are available. A mounted widget joins an
  in-flight request or claims a ready ad exclusively, then the library prepares
  one replacement. Other exact sizes, templates, styles and unit overrides
  load on first use.
- App Open resume checks a real background transition, consent, entitlement,
  paywall and scoped external-flow suppression, cooldown, freshness, and the
  fullscreen mutex. A late load stays cached for another opportunity; it does
  not present on a screen the user has left.
- SDK callbacks provide impression, click, and paid-value events. A loaded ad
  or accepted show call is not counted as an impression.

## Native presentation

Both Android and iOS bundle the supplied `bigNative` and horizontal
`mediumNative` structures. `bigNative` defaults to 280 logical pixels with
full-width square-corner media, icon/header, optional body and SDK rating or
store assets when present, AdChoices, and a CTA. `mediumNative` defaults to
128 logical pixels with a 120×120 media area. Smaller requested heights are
clamped to preserve the video media minimum. Background, text, CTA colors and
the default 10dp/pt CTA/card radius can be overridden. The compact `small`
variant uses Google's official template.

The iOS sample ran with Google test native ads and AdMob Native Validator
reported no implementation issues for both bundled layouts. That check does
not establish production fill or performance.

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues. |
| `flutter test --concurrency=1` | 191 tests passed. |
| `flutter build apk --debug` in `example/` | Passed. |
| `flutter build ios --simulator --debug --no-codesign` in `example/` | Passed with CocoaPods. |
| Swift Package Manager iOS simulator build and launch | Passed; both native test ads rendered. |
| Fresh consumer app with a path dependency: Android APK and iOS simulator (Swift Package Manager) | Passed. |
| Fresh consumer app: iOS CocoaPods with generated `use_frameworks!` | Failed on `google_mobile_ads` 9.1.0 at `GoogleMobileAds_Beta.h`; static linkage did not help. Passed with a host-side 9.0.0 pin and the generated `use_frameworks!` retained. The package supports both versions to avoid conflicts with existing projects. See [upstream issue](https://github.com/googleads/googleads-mobile-flutter/issues/1472). |
| Automated fresh-consumer smoke script | Passed locally for Android APK with 9.1.0, iOS CocoaPods with a direct 9.0.0 host pin, and iOS Swift Package Manager with 9.1.0; CI runs all three. |
| `flutter pub publish --dry-run` | Zero warnings; no publication performed. |

Tests use fake SDK callbacks for lifecycle, request ownership, consent and
cache behavior. Device smoke checks show only sample rendering. Real-device
consent flows, all ad formats, mediation, slow/offline recovery, accessibility,
and actual AdMob request-to-impression metrics still require host-app and
production verification. The package cannot guarantee an 80%+ match or show
rate: inventory, account status, geography, placement and user behavior also
affect those measurements.

See [ad-delivery measurement](DELIVERY_AUDIT.md),
[native preload lifecycle](NATIVE_PRELOAD_LIFECYCLE.md), and
[resume lifecycle](RESUME_APP_OPEN_LIFECYCLE.md) for the relevant flows.
