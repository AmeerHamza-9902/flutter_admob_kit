# Changelog

## Unreleased

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
* Remove ownership-less mutex APIs; minimum supported versions are Flutter 3.38.1, Dart 3.10, and google_mobile_ads 9.1.0.
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
