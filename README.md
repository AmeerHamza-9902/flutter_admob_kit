# flutter_admob_kit

A lightweight Flutter wrapper around Google Mobile Ads for Android and iOS. Configuration stays in Dart. There is no Remote Config, analytics backend, custom network client, or extra preload pool.

## Features

- Interstitial, rewarded, App Open, banner and native template ads.
- Automatic UMP consent and a privacy settings button.
- Shared premium gating and fullscreen presentation ownership.
- Single-flight fullscreen loads, bounded retries and stale-callback protection.
- Runnable Android and iOS example apps using Google test IDs.

## Requirements and platform setup

Use Flutter **3.38.1+**, Dart **3.10+**, and `google_mobile_ads >=9.1.0 <10.0.0`. Earlier plugin versions do not provide all APIs used here. Version 4.0.0 introduces breaking changes from 3.x; review the migration notes below.

```yaml
dependencies:
  flutter_admob_kit: ^4.0.0
```

Run `flutter pub get` after adding the dependency.

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
      adReadinessTimeout: Duration(seconds: 12), // Default explicit wait.
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

For a splash or another flow that deliberately waits, call `await AdMobKit.appOpen.waitUntilReady()` before `show(true)`. The default wait limit is `AdMobConfig.adReadinessTimeout` (12 seconds); override one opportunity with `waitUntilReady(timeout: const Duration(seconds: 5))`. A `false` result means the ad was unavailable before the deadline. The underlying SDK request continues and its late result can serve a later opportunity; it never appears automatically. Consent UI and SDK initialization are outside this timer. Banner and native preload controllers also expose `waitUntilReady(...)` with the same global default and a per-call `timeout` override. Normal navigation should use cached ads immediately and should not await readiness.

If an ad-unit change happens during a native fullscreen request, the replacement waits for that request to settle. Callers waiting for the replacement share one future; cancellation, eligibility invalidation, or manager disposal settles them without starting overlapping requests.

Failures retry at **30, 60, and 120 seconds**, with one timer. After exhaustion, automatic retries stop; fullscreen opportunities cannot start a new cycle for five minutes. Disposal, entitlement, and consent/config invalidation cancel retries. No watchdog starts a second request merely because a native load is slow. An invalidated fullscreen request must settle before a replacement is issued.

Interstitial/rewarded cache age is capped at one hour and App Open at four hours; shorter configured values are supported. Expiry is checked on use/preload. There is no continuous expiry refresh timer. `autoPreload: false` disables eager initialization/config/eligibility preloads; explicit show/preload and post-consumption replacement retain their documented behavior.

### Delivery diagnostics

`AdMobKit.addEventListener(listener)` is optional and local. `AdEventType.request`, `loaded`, `loadFailed`, `cacheHit`, `cacheMiss`, `opportunity`, `presentationAccepted`, `presentationFailed`, `impression`, `dismissed`, `expired`, `invalidated`, `waitTimedOut`, and `skipped` help trace the fullscreen path. `AdEvent.reason` explains skips such as background state, cooldown, active fullscreen presentation, or unavailable cache. Banner/native preload events cover requests, loads, failures, cache handoff and SDK impressions. Keep listeners lightweight and remove them with `removeEventListener` when no longer needed. Only the SDK `impression` callback confirms an impression; `presentationAccepted` is not a substitute.

Calculate a **client load-success proxy** as loaded requests / completed requests; use AdMob reporting for its exact request match rate. Calculate **loaded-ad show rate at eligible opportunities** as accepted presentations / `cacheHit` events whose `reason` is `presentation`, **SDK impression rate** as SDK impressions / accepted presentations, and **impressions per eligible session** as SDK impressions / eligible sessions. Segment by format, placement, platform, consent state and network. The 90%+ target applies only to the second ratio; inventory, user flow and network can still limit every metric. Do not count a cache hit whose reason is `preload` as a presentation opportunity. App code should log session and placement identifiers separately if those cuts are needed.

The [delivery audit and real-device test procedure](doc/DELIVERY_AUDIT.md) lists the main non-impression paths and a test-ad checklist for both platforms.

## App Open

With `autoResumeAppOpen: true`, a real background-to-foreground transition can show a ready ad, subject to consent, entitlement, foreground state, cooldown, paywall suppression, freshness, and the fullscreen mutex. Cold-start resume does not show an ad. Background transitions caused by an already-presented fullscreen ad do not trigger another App Open ad.

```dart
await AdMobKit.appOpen.show(true); // Optional manual opportunity.
```

Place App Open opportunities around loading/return experiences, following [Google's placement guidance](https://developers.google.com/admob/flutter/app-open). The SDK cannot determine whether every host screen is an appropriate ad placement.

## Native layout update on GitHub

The following layout changes are unreleased and available from this repository only; pub.dev 4.0.0 remains unchanged. To try them before the next release, use the Git dependency and rebuild the native app (hot reload is insufficient):

```yaml
dependencies:
  flutter_admob_kit:
    git:
      url: https://github.com/AmeerHamza-9902/flutter_admob_kit.git
      ref: main
```

## Banner and native placements

```dart
const BannerAdWidget(); // Native-size 320×50 banner.
const BannerAdWidget.small(); // Adaptive to available container width.
const BannerAdWidget.large(); // Base 320×100; FittedBox fills width.
const BannerAdWidget.mediumRectangle(); // Base 300×250; FittedBox fills width.
const BannerAdWidget.inlineAdaptive(); // Full width, maximum height 50dp.
const BannerAdWidget.inlineAdaptiveLarge(); // Full width, maximum height 250dp.
const BannerAdWidget.inlineAdaptiveLarge(maxHeight: 300); // Custom height cap.
const BannerAdWidget(size: AdSize.largeBanner); // Custom supported fixed size.
const NativeAdWidget.small(); // Minimum height 90.
const NativeAdWidget.mediumNative(); // Horizontal card; default height 128.
const NativeAdWidget.bigNative(); // Large splash card; 280 Android / 320 iOS.
```

### Preload an upcoming banner on splash

Keep one controller in the parent that owns both routes. After `AdMobKit.initialize` and consent complete, preload only if onboarding will actually be visited:

```dart
final onboardingBanner = BannerPreloadController();

// Splash: start loading without delaying navigation.
unawaited(onboardingBanner.preloadLarge()); // import dart:async

// Onboarding: pass the SAME controller and matching banner format.
BannerAdWidget.large(preloadController: onboardingBanner);

// Parent disposal (after the routes no longer need the controller):
onboardingBanner.dispose();
```

For other formats use `preloadMediumRectangle()`, `preloadSmall(width: destinationWidth)`, or `preloadInlineAdaptive(width: destinationWidth, maxHeight: 250)` with the matching widget and maximum height. Account for destination padding/safe areas in the width. Ready ads are handed to one placement; widgets joining an in-flight preload wait for the same request. A second placement gets its own ad. Size mismatches discard the unused preload and load the correct size. After handoff the widget owns disposal; cancelling a pending destination releases its reserved load.

Unused loaded ads expire after two minutes without automatic replenishment. Pending loads time out after one minute. Consent/entitlement/configuration changes invalidate unused preloads. There is no background retry loop or automatic splash request; failed/missing preloads fall back to the existing bounded widget retry flow. Do not await preload to block navigation. Slow networks can still leave a loading placeholder.

Preloading cannot guarantee 80% match/show rate or CTR. Loading an ad that the user never reaches can lower show rate, so preload only the next confirmed placement. SDK impression/click callbacks remain the source of events; no impressions or clicks are simulated. See [AdMob metric definitions](https://support.google.com/admob/table/9462111?hl=en).

Native templates default to a white background. `bigNative` is the large splash card with full-width square-corner media, a 52dp icon, headline/body, AdChoices, optional SDK rating/store assets, and a full-width CTA. It defaults to 280 logical pixels on Android and a 320 minimum on iOS. `mediumNative` is a horizontal card that defaults to 128dp: media on the left and headline, advertiser, body, AdChoices and CTA on the right. Its Android media and optional text adapt to the supplied height. Missing optional assets collapse cleanly. On iOS, `bigNative` uses Google's official medium template and `mediumNative` uses the official compact template.

Developers can override the same style properties:

```dart
const NativeAdWidget.mediumNative(
  style: NativeAdStyle(
    backgroundColor: Color(0xFF101827),
    primaryTextColor: Colors.white,
    secondaryTextColor: Color(0xFFD1D5DB),
    callToActionColor: Color(0xFF2563EB),
    callToActionTextColor: Colors.white,
    cornerRadius: 12,
  ),
);

const NativeAdWidget.bigNative(style: NativeAdStyle(/* same options */));
```

`mediumNative(height: 130)` reserves exactly 130 logical pixels for both the
native card and its horizontal loading skeleton. Any positive finite height
can be supplied; the Android card reduces optional copy at compact sizes so
its headline and CTA have room. Keep ad assets readable at the chosen size.

To show an upcoming native placement immediately, create one controller per
destination, preload while the user is on the preceding screen, and pass that
same controller to the destination widget:

```dart
final settingsNative = NativePreloadController();
unawaited(settingsNative.preloadMediumNative());

NativeAdWidget.mediumNative(preloadController: settingsNative);
```

Repeated matching preload calls share one request. Each loaded native view can
be handed to one widget only; use a separate controller for each placement.

Both bundled Android factories register once per Flutter engine before a custom native request. No `MainActivity` changes or manual registration are required. Native SDK asset registration retains click/impression tracking and AdChoices. The former `NativeAdWidget.medium()` constructor remains as a deprecated compatibility alias for `bigNative()`.

Stable widget rebuilds do not request again. Adaptive banners reload on a real available-width change. Inline adaptive banners use the container width and the actual SDK height after loading; 50dp and 250dp are default maximums, not guaranteed creative heights. Use them in scrolling content. Changing width or the height cap requests the new size once. `fitToWidth: true` uses a proportional `FittedBox`: a 300×250 rectangle rendered at 360dp width occupies 300dp height. `large` and `mediumRectangle` enable this by default; set `fitToWidth: false` to retain their native 320×100 and 300×250 sizes respectively. Inline/anchored adaptive constructors fill the available width using SDK sizing, without scaling by default. See [inline adaptive sizing](https://developers.google.com/admob/flutter/banner/inline-adaptive). Reserve sufficient space and keep ads away from navigation/tap targets. Native templates require a bounded width of at least 320 logical pixels; test both platforms and text sizes. Big and small template heights retain their minimums; `mediumNative` uses the supplied positive height. See [Google's template sizing](https://developers.google.com/admob/flutter/native/templates).

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

Verified with Flutter 3.44.1 and Dart 3.12.1: 115 automated tests passed, static analysis passed, and Android debug APK and iOS simulator builds passed. Both example home screens rendered; an iOS test banner rendered. Android returned a no-fill response during the smoke run. Live consent configuration, all-format device testing and network recovery still need host verification; see the [technical audit](doc/FINAL_AUDIT.md).

## Migration from 3.x

- UMP flow defaults to enabled; disabling it no longer bypasses the shared gate.
- SDK initialization failures propagate instead of being silently ignored.
- Removed ownership-less `tryAcquire`/`release`; advanced mutex users must retain the token from `acquireToken` and use `releaseWithToken`.
- Raised minimum Flutter/Dart/plugin requirements to the verified API baseline.
- Medium rectangles no longer scale their native creative.
- Use the central facade rather than constructing independent managers for the same unit.
- Removed the unused `AdMobKit.instance` alias and ignored `PaywallCloseGuard.adUnitId` parameter; use static APIs and central configuration.

## License

MIT. See [LICENSE](LICENSE).
