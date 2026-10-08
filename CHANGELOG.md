# Changelog

## Unreleased

- Pin `google_mobile_ads` to 9.0.x until its 9.1.0 non-modular iOS header
  regression is resolved. A fresh CocoaPods app with `use_frameworks!`, the
  Android APK, and all package tests build with 9.0.0.

- Use each native template's minimum height when a caller supplies a non-finite
  value; avoid an unbounded ad or shimmer layout.

- Move banner/native preload ownership fully inside the library. Remove the
  public preload controller exports, widget `preloadController` parameters and
  public inline cache accessors; placements now join library caches directly.

- Set the default native CTA and card corner radius to 10dp/pt while keeping
  developer overrides and square-corner media.

- Package the iOS native layouts for both Swift Package Manager and CocoaPods.

- Match the supplied horizontal and large native card structure on iOS with
  bundled factories, including the 120×120pt video MediaView, header assets,
  optional body, AdChoices, developer colors and CTA. The iOS video test ad
  now passes AdMob Native Validator without the small-MediaView warning.

- Keep Android `mediumNative` media at 120×120dp and its headline on one line.
  Both bundled Android layouts hide optional body copy when the card
  cannot show its first 90 characters; the large layout no longer shortens its
  required headline to make room. Clamp smaller requested medium card heights
  to 128dp for video support.

- Add named interstitial, rewarded and manual App Open placements with separate
  caches per unit, automatic eligible preloading, live unit-ID replacement and
  `AdEvent.placementId`. Bound initial fullscreen load attempts with a shared
  two-slot FIFO queue and let stalled slots yield after 20 seconds without
  duplicating the underlying request. The default-format API remains available.

- Forward Google Mobile Ads paid-value callbacks for fullscreen, banner and
  native ads (including library-managed preloads) through the local `AdEvent`
  stream with micros, currency and precision. The callback is account-dependent
  and does not alter ad requests or presentation. Exhaustive `AdEventType`
  switches must handle the new `paid` value.

- Preserve premium entitlement across routine `updateConfig` calls; only an
  explicit `setEntitled(false)` re-enables ad eligibility.

- Keep fullscreen cached ads tied to their requested ad unit, and defer a new
  unit's request until the previous native request settles, sharing a wait for
  the replacement and settling it on disposal. Count eligible
  opportunities that arrive during loading as cache misses. Ignore duplicate
  banner/native preload load callbacks without evicting a valid cached ad.

- Add a configurable 12-second default readiness wait with per-call overrides
  for fullscreen and banner/native preload controllers. A wait timeout leaves
  the native request in flight and never presents a late ad automatically.
- Add optional delivery diagnostics separating requests, cache state, eligible
  opportunities, accepted presentations, SDK impressions, invalidations,
  failures and skip reasons. This adds `AdEventType` values; clients with an
  exhaustive switch over that enum must handle the new cases. Dispose
  duplicate stale fullscreen callbacks.
- Settle readiness waits on invalidation and fix pending native claim cleanup
  when consent or entitlement changes.

- Match the `mediumNative` loading shimmer and Android layout to any positive
  developer-specified height; use a compact horizontal skeleton without overflow.

- Add `NativePreloadController` so high-probability destination screens can
  receive an already-loaded native view without issuing a second request.

- Rename the large splash native template to `bigNative`, add the horizontal
  120dp `mediumNative` template, and support the same background, text, CTA,
  and corner styling on both bundled Android layouts. Keep `medium()` as a
  deprecated compatibility alias for `bigNative()`.

- Ignore notification-shade-only `inactive → resumed` transitions and add a
  scoped resume suppression API for camera, gallery, picker, and permission UI.

- Recognize very quick Android Recent Apps `inactive → resumed` transitions even
  when the OS omits `hidden` and `paused`, then present at the first safe
  `resumed` callback.

- Correct the Android App Open demo unit to Google's current official test ID so test-mode resume requests do not fail with `Publisher data not found`.

- Show a primed resume App Open ad after genuine background returns of any duration, including sub-second returns, without letting an earlier foreground fullscreen ad suppress the next resume.

- Suppress resume App Open for fullscreen-ad lifecycle cycles even when dismissal arrives before background/resume callbacks; preserve the next genuine resume and paywall suppression.

- Add opt-in `BannerPreloadController` for splash-to-next-screen handoff, pending-request reuse, exact format/size matching, single-placement ownership, short cache expiry and consent/configuration invalidation.

- Add `BannerAdWidget.large()` for standard 320×100 banners with optional proportional full-width fitting.

- Add compact (50dp maximum) and large (250dp maximum) inline adaptive banners with customizable height caps and SDK-reported loaded sizes. Enable proportional FittedBox width fitting for medium rectangles by default.

- Default Android medium native cards to 280dp, expand media with custom taller heights, and adapt text line counts to available space without reloading ads.

* Remove medium media corner rounding, set CTA corners to 10dp, display SDK-provided rating stars/score and store, use 16sp three-line headlines and 13sp two-line bodies, and reserve at least 380dp on Android.

* Default native template backgrounds to white while preserving developer color overrides.
* Bundle the Android medium media/header/pill-CTA layout with native asset registration, optional-asset handling and automatic per-engine factory setup.
* Keep small and iOS layouts on Google templates; document full native rebuild requirements.


## 4.0.0

* Complete UMP privacy entry-point support with `PrivacyConsentButton`, requirement/busy/error state, initialization parameters, and separate initial-consent/privacy-form results.
* Add consent/form lifecycle regression tests and correct the native form method name in existing tests.
* Remove unused `AdMobKit.instance`, ignored paywall `adUnitId`, duplicate inline gate checks, and redundant comments/example IDs.

* Consolidate fullscreen load/cache/retry/presentation ownership; prevent show-while-loading requests and stale callback corruption.
* Keep exact fullscreen leases and presented native resources until dismissal, including configuration/entitlement changes.
* Centralize fail-closed UMP readiness for all formats; enable automatic consent by default and surface initialization errors.
* Add conservative bounded retries, inline resource ownership during loads, adaptive container sizing, and equivalent native-style comparison.
* Reuse the central interstitial in paywall guards, suppress duplicate dismiss actions, and account for nested paywalls.
* Remove ownership-less mutex APIs; minimum supported versions are Flutter 3.38.1, Dart 3.10, and google_mobile_ads 9.0.0.
* Expand request-count, slow-load, retry, stale callback, entitlement, initialization, and widget tests.
* Correct setup documentation and unsupported performance/metric claims.

* Central Dart configuration, fullscreen managers, UMP integration, premium entitlement, and small/medium native templates.
* Previous release notes incorrectly referenced an `AdLifecycleMixin`, click-counter behavior, and `showOnResumeAppOpen()` absent from this source. Those claims have been removed.

## 3.0.6

* **Fix:** Removed unused `_lastAdUnitId` field from `InterstitialAdManager`
* **Fix:** Updated `google_mobile_ads` constraint to `>=5.1.0 <9.0.0` — now supports v8
* **Fix:** Shortened `pubspec.yaml` description to meet 60-180 character requirement

## 3.0.4

* **Fix:** Static analysis warnings resolved
* **Fix:** Updated SDK constraints to `>=3.3.0 <4.0.0`
* **Fix:** Flutter constraint updated to `>=3.19.0`
* **Fix:** Topics reduced to 5 (pub.dev limit)

## 3.0.3

* **Fix:** Broadened `google_mobile_ads` constraint to `>=5.1.0 <7.0.0`
* **Fix:** Pure Dart configuration — pass ad unit IDs directly

## 3.0.0

* **New:** `RewardedInterstitialAdManager` added
* **New:** Automatic ad expiry — Interstitial: 1hr, AppOpen: 4hr
* **New:** Auto retry on load failure (3 attempts: 2s → 4s → 6s backoff)
* **New:** `isAdReady` getter on all managers
* **New:** `onAdClicked` and `onAdImpression` callbacks
* **New:** `placeholder` parameter on `NativeAdWidget`
* **Fix:** `onAdDismiss` fires correctly before `onAdDismissed`
* **Fix:** `resetCoins()` properly resets coin counter

## 2.0.0

* Zero external configuration dependency — pure Dart configuration
* ViewModel-based pattern matching Swift AdMobKit

## 1.0.0

* Initial release
