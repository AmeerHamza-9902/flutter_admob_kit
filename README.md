# flutter_admob_kit

A lightweight Flutter wrapper around Google Mobile Ads for Android and iOS. Configuration stays in Dart. There is no Remote Config, analytics backend, custom network client, or extra preload pool.

## Features

- Interstitial, rewarded, App Open, banner and native template ads.
- Automatic UMP consent and a privacy settings button.
- Shared premium gating and fullscreen presentation ownership.
- Single-flight fullscreen loads, bounded retries and stale-callback protection.
- Runnable Android and iOS example apps using Google test IDs.

## Requirements and platform setup

Use Flutter **3.38.1+**, Dart **3.10+**, and `google_mobile_ads >=9.1.0 <10.0.0`. Earlier plugin versions do not provide all APIs used here. The package version remains 4.0.0; these unreleased changes require migration review.

These changes are available from GitHub and have not been released to pub.dev. To use this repository version:

```yaml
dependencies:
  flutter_admob_kit:
    git:
      url: https://github.com/AmeerHamza-9902/flutter_admob_kit.git
      ref: main
```

Pin `ref` to a reviewed commit for reproducible application builds. The existing pub.dev `^4.0.0` release does not include these unreleased changes.

This repository contains a Dart package and an Android/iOS example host using official Google test app IDs. Configure your own consuming application as follows. In your application's `android/app/src/main/AndroidManifest.xml`, add your **app ID** inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY" />
```

In `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

App IDs use `~`; ad unit IDs use `/`. Follow Google's [Flutter setup](https://developers.google.com/admob/flutter/quick-start) and [iOS setup](https://developers.google.com/admob/ios/quick-start) for current deployment targets, SKAdNetwork entries, and mediation requirements. The resolved plugin uses Android GMA 25.4.0 and iOS GMA ~13.7 (13.11.0 resolved in the example). Android initialization/loading optimization flags already default to true in GMA 24+, so no redundant flags or Dart isolates are added. See [Google's optimization guidance](https://developers.google.com/admob/android/optimize-initialization).

## Initialization and consent

```dart
import 'package:flutter/material.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AdMobKit.setEntitled(false); // Restore your real entitlement first.
  await AdMobKit.initialize(
    config: const AdMobConfig(
      testMode: true, // Use test ads during development.
      enableUmpConsent: true, // Default; resolves the required UMP form.
      android: AdPlatformConfig(
        interstitial: 'YOUR_ANDROID_INTERSTITIAL_UNIT_ID',
        rewarded: 'YOUR_ANDROID_REWARDED_UNIT_ID',
        appOpen: 'YOUR_ANDROID_APP_OPEN_UNIT_ID',
        banner: 'YOUR_ANDROID_BANNER_UNIT_ID',
        native: 'YOUR_ANDROID_NATIVE_UNIT_ID',
      ),
      ios: AdPlatformConfig(
        interstitial: 'YOUR_IOS_INTERSTITIAL_UNIT_ID',
        rewarded: 'YOUR_IOS_REWARDED_UNIT_ID',
        appOpen: 'YOUR_IOS_APP_OPEN_UNIT_ID',
        banner: 'YOUR_IOS_BANNER_UNIT_ID',
        native: 'YOUR_IOS_NATIVE_UNIT_ID',
      ),
    ),
  );
  runApp(const MyApp());
}
```

Set `testMode: false` with real unit IDs for production. Omit formats you do not intend to use. Initialization is single-flight and propagates SDK initialization errors; the host can display its normal UI and retry initialization after resolving an error. Accessing fullscreen managers before initialization throws a descriptive `StateError`.

Every format requires successful initialization, a non-entitled user, and UMP's actual `canRequestAds()` result. Disabling `enableUmpConsent` disables automatic form management **only**; it does not bypass consent. In that mode the host must complete UMP and call `AdMobKit.consent.canRequestAds()` to refresh the shared gate. There is no fallback that infers permission from a consent status enum. Widgets mounted before readiness wait for the gate.

The initial Google consent form is implemented by the library and shown automatically when UMP requires it. Configure and publish your app's message under **AdMob → Privacy & messaging**, and use the matching native AdMob app ID. A test ad unit ID alone does not force the consent form to appear.

Add the library's settings button to let users revisit their choices:

```dart
const PrivacyConsentButton();

// Optional localized label:
const PrivacyConsentButton(child: Text('Privacy settings'));
```

The button appears only when UMP requires a privacy entry point and disables itself while a form is open. It remains available to premium users when required. For custom UI:

```dart
final required = AdMobKit.consent.isPrivacyOptionsRequired;
final shown = await AdMobKit.showPrivacyConsentForm();
final error = AdMobKit.consent.lastError;
```

`ConsentManager` is listenable: custom UI can react to `isBusy` and `isPrivacyOptionsRequired`. Privacy-form success is separate from permission to request ads; dismissing a form successfully does not mean personalized ads are allowed.

Optional UMP parameters can be passed at initialization:

```dart
await AdMobKit.initialize(
  config: const AdMobConfig(testMode: true),
  consentParameters: ConsentRequestParameters(
    consentDebugSettings: ConsentDebugSettings(
      debugGeography: DebugGeography.debugGeographyEea,
      testIdentifiers: ['YOUR_UMP_TEST_DEVICE_HASH'],
    ),
  ),
);
```

Use debug geography only with registered test devices during development; omit debug settings in production. The same parameter supports `tagForUnderAgeOfConsent` when applicable to your app.

The gate closes during consent changes and refreshes after completion, invalidating cached ads and retries when unavailable. Google describes entry-point requirements and error recovery in its [UMP guide](https://developers.google.com/admob/flutter/privacy).

## Fullscreen ads

```dart
// Use interstitials at a natural transition in your app.
final accepted = await AdMobKit.interstitial.show(true);
await AdMobKit.interstitial.show(false); // No load, preload, or show.

await AdMobKit.rewarded.show(true, onReward: (reward) {
  // Grant the SDK-supplied reward. Check mounted before updating widget UI.
});
```

`show()` reports whether the SDK accepted a presentation attempt; it is **not** an impression or a dismissal future. Actual `shown`, `impression`, `clicked`, and `dismissed` events come from SDK callbacks. Reward callbacks are deduplicated per presented ad and can arrive after dismissal with some mediation adapters.

Each fullscreen format has one cache and one load. Initialization preloads configured formats after consent; closing a consumed ad requests one replacement. Repeated preload/show calls reuse the current load/cache. When unavailable, `show(true)` may prime a load but returns immediately without waiting for a slow network. It never auto-shows a late result after the opportunity has passed.

Failures retry at **30, 60, and 120 seconds**, with one timer. After exhaustion, automatic retries stop; fullscreen opportunities cannot start a new cycle for five minutes. Disposal, entitlement, and consent/config invalidation cancel retries. No watchdog starts a second request merely because a native load is slow. An invalidated fullscreen request must settle before a replacement is issued.

Interstitial/rewarded cache age is capped at one hour and App Open at four hours; shorter configured values are supported. Expiry is checked on use/preload. There is no continuous expiry refresh timer. `autoPreload: false` disables eager initialization/config/eligibility preloads; explicit show/preload and post-consumption replacement retain their documented behavior.

## App Open

With `autoResumeAppOpen: true`, a real background-to-foreground transition can show a ready ad, subject to consent, entitlement, foreground state, cooldown, paywall suppression, freshness, and the fullscreen mutex. Cold-start resume does not show an ad. Background transitions caused by an already-presented fullscreen ad do not trigger another App Open ad.

```dart
await AdMobKit.appOpen.show(true); // Optional manual opportunity.
```

Place App Open opportunities around loading/return experiences, following [Google's placement guidance](https://developers.google.com/admob/flutter/app-open). The SDK cannot determine whether every host screen is an appropriate ad placement.

## Banner and native placements

```dart
const BannerAdWidget(); // Native-size 320×50 banner.
const BannerAdWidget.small(); // Adaptive to available container width.
const BannerAdWidget.mediumRectangle(); // Native-size 300×250.
const NativeAdWidget.small(); // Minimum height 90.
const NativeAdWidget.medium(); // Minimum height 320.
```

Stable widget rebuilds do not request again. Adaptive banners reload on a real available-width change. Banners are never stretched with `FittedBox`; the legacy `fitToWidth` option centers the native-size ad. Reserve sufficient space and keep ads away from navigation/tap targets. Native templates require a bounded width of at least 320 logical pixels; test both platforms and text sizes. Custom heights are clamped to the template minimum. See [Google's template sizing](https://developers.google.com/admob/flutter/native/templates).

Each mounted placement owns its native resource, including while loading. Separate visible placements legitimately request separate ads; an `AdWidget` cannot share one native view across placements. Widget retries are bounded to three and cancelled on unmount or invalidation. Successful banners may refresh according to AdMob's SDK/server settings; the wrapper does not add a success refresh loop. Keep stable widget keys to preserve placement resources.

## Premium and configuration

```dart
AdMobKit.setEntitled(true);  // Works before or after initialize.
AdMobKit.setEntitled(false); // Eligible automatic preloads may resume.

AdMobKit.updateConfig(AdMobKit.config.copyWith(testMode: true));
```

Entitlement is stored centrally. Cached resources are invalidated and inline placements collapse. Native network work already submitted cannot be recalled; late results are discarded. An already-presented fullscreen ad retains its exact lease until it closes. Changing configuration never forcibly disposes that presentation or releases its lease early.

## Paywall close guard

```dart
PaywallCloseGuard.builder(
  isEntitled: userIsPremium,
  onDismiss: () => Navigator.of(context).pop(),
  builder: (context, dismiss, loading) => Scaffold(
    body: TextButton(onPressed: dismiss, child: const Text('Close')),
  ),
)
```

The guard reuses `AdMobKit.interstitial`; it never creates a second manager. Configure its ad unit through `AdMobConfig`; the ignored legacy `adUnitId` parameter has been removed. Nested guards retain App Open suppression until all close. If an ad is unavailable, dismiss proceeds immediately. Repeated close taps cannot launch multiple presentations or dismiss twice. The timeout only limits the builder's loading indicator; it never holds navigation while waiting for a load.

## Events and practical limits

Use `AdMobKit.addEventListener(listener)` and `removeEventListener(listener)` for optional local lifecycle observation. Banner/native impression and click events are forwarded from native callbacks. No event data is transmitted externally by this package. Paid/revenue callbacks are not currently exposed; no revenue is inferred from load/show calls.

The wrapper can reduce duplicate requests and lifecycle losses. It cannot guarantee fill, match rate, show rate, CTR, revenue, or always-ready ads. Demand, geography, account status, inventory, mediation, network conditions, and user behavior remain external factors. Never treat more requests or accidental taps as a monetization strategy.

## Run the example and checks

```sh
git clone https://github.com/AmeerHamza-9902/flutter_admob_kit.git
cd flutter_admob_kit
flutter pub get
flutter analyze
flutter test
cd example
flutter pub get
flutter run
```

The example includes native test app IDs; production apps must supply their own app and ad unit IDs. See [example setup](example/README.md).

Verified with Flutter 3.44.1 and Dart 3.12.1: 115 automated tests passed, static analysis passed, and Android debug APK and iOS simulator builds passed. Both example home screens rendered; an iOS test banner rendered. Android returned a no-fill response during the smoke run. Live consent configuration, all-format device testing and network recovery still need host verification; see the [technical audit](docs/FINAL_AUDIT.md).

## Unreleased migration notes

- UMP flow defaults to enabled; disabling it no longer bypasses the shared gate.
- SDK initialization failures propagate instead of being silently ignored.
- Removed ownership-less `tryAcquire`/`release`; advanced mutex users must retain the token from `acquireToken` and use `releaseWithToken`.
- Raised minimum Flutter/Dart/plugin requirements to the verified API baseline.
- Medium rectangles no longer scale their native creative.
- Use the central facade rather than constructing independent managers for the same unit.
- Removed the unused `AdMobKit.instance` alias and ignored `PaywallCloseGuard.adUnitId` parameter; use static APIs and central configuration.

## License

MIT. See [LICENSE](LICENSE).
