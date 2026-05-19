# Changelog

## 3.0.2

* **Fix:** Removed unused `_lastAdUnitId` field from `InterstitialAdManager`
* **Fix:** Updated SDK constraints to `>=3.3.0 <4.0.0`
* **Fix:** Flutter constraint updated to `>=3.19.0`
* **Fix:** Topics reduced to 5 (pub.dev limit)

## 3.0.1

* **Fix:** Broadened `google_mobile_ads` constraint to `>=5.1.0 <7.0.0` — compatible with v5 and v6
* **Fix:** Removed JSON config (`AdsConfig`, `ConfigLoader`) — not needed, pass ad unit IDs directly

### ⚠️ google_mobile_ads version conflict?

If you see this error:

```
Because flutter_admob_kit depends on google_mobile_ads >=5.1.0 <7.0.0
and your_app depends on google_mobile_ads ^X.X.X, version solving failed.
```

Add this to your app's `pubspec.yaml` and run `flutter pub get`:

```yaml
# Use whichever version your app needs:

# For v5
dependency_overrides:
  google_mobile_ads: ^5.3.1

# For v6
dependency_overrides:
  google_mobile_ads: ^6.0.0
```

## 3.0.0

* **New:** `RewardedInterstitialAdManager` added
* **New:** Automatic ad expiry — Interstitial: 1hr, AppOpen: 4hr
* **New:** Auto retry on load failure (3 attempts: 2s → 4s → 6s backoff)
* **New:** `isAdReady` getter on all managers (loaded + not expired)
* **New:** `onAdClicked` callback on `BannerAdWidget` and `NativeAdManager`
* **New:** `onAdImpression` callback on `NativeAdManager`
* **New:** `placeholder` parameter on `NativeAdWidget`
* **Fix:** `onAdDismiss` (adWillDismiss) fires correctly before `onAdDismissed`
* **Fix:** `resetCoins()` properly resets coin counter

## 2.0.0

* Removed Firebase Remote Config — local JSON only
* ViewModel-based pattern matching Swift AdMobKit

## 1.0.0

* Initial release
