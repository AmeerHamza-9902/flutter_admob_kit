# Changelog

## 3.0.7

* **New:** `onAdClicked` and `onAdImpression` callbacks on all fullscreen ad managers
* **Fix:** `showOnResumeAppOpen()` now pre-loads the ad before showing
* **Fix:** Updated `flutter_lints` to `^6.0.0`
* **Fix:** Removed stray directories and `.DS_Store` files from repository
* **Fix:** Removed unnecessary `firebase_core` dependency from example app
* **Fix:** Added `analysis_options.yaml`

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
* **Fix:** Removed JSON config — pass ad unit IDs directly

### ⚠️ google_mobile_ads version conflict?

If you see a conflict error, add this to your `pubspec.yaml`:

```yaml
dependency_overrides:
  google_mobile_ads: ^8.0.0
```

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

* Removed Firebase Remote Config — no Firebase dependency
* ViewModel-based pattern matching Swift AdMobKit

## 1.0.0

* Initial release
