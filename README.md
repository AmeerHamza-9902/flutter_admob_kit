# flutter_admob_kit

A lightweight Flutter wrapper around Google Mobile Ads for Android and iOS. Configuration stays in Dart. The library manages short-lived ad caches without a Remote Config or analytics backend.

## Features

- Interstitial, rewarded, App Open, banner and native template ads.
- Automatic UMP consent and a privacy settings button.
- Shared premium gating and fullscreen presentation ownership.
- Single-flight fullscreen loads, bounded retries and stale-callback protection.
- Runnable Android and iOS example apps using Google test IDs.

## Requirements and platform setup

Use Flutter **3.38.1+**, Dart **3.10+**, and `google_mobile_ads >=9.0.0 <10.0.0`. Version 4.0.0 introduced breaking changes from 3.x; review the migration notes below.

For version 4.0.1:

```yaml
dependencies:
  flutter_admob_kit: ^4.0.1
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
  runApp(const MyApp());
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
}
```

Set `testMode: false` with real unit IDs for production. Omit formats you do not intend to use. Render the app before awaiting initialization so a slow first-install consent flow or SDK startup does not hold the first Flutter frame; widgets mounted early wait for the library's consent and initialization gate. Gate fullscreen buttons with `AdMobKit.canRequestAds` and rebuild them from `AdMobKit.configNotifier`, as the example does. Initialization is single-flight and propagates SDK initialization errors; the host can display its normal UI and retry initialization after resolving an error. Accessing fullscreen managers before initialization throws a descriptive `StateError`.

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

Each default fullscreen format has one cache and one load. Initialization preloads configured formats after consent; closing a consumed ad requests one replacement. Repeated preload/show calls reuse the current load/cache. When unavailable, `show(true)` may prime a load but returns immediately without waiting for a slow network. It never auto-shows a late result after the opportunity has passed.

For apps with different fullscreen ad units on different screens, register named placements before or after initialization:

```dart
AdMobKit.registerFullscreenPlacements(const [
  FullscreenPlacement.interstitial(
    id: 'settings',
    androidId: 'YOUR_ANDROID_SETTINGS_UNIT',
    iosId: 'YOUR_IOS_SETTINGS_UNIT',
  ),
  FullscreenPlacement.interstitial(
    id: 'history',
    androidId: 'YOUR_ANDROID_HISTORY_UNIT',
    iosId: 'YOUR_IOS_HISTORY_UNIT',
  ),
]);

// Once initialization and consent are complete:
final accepted = await AdMobKit.interstitialFor('settings').show(true);
```

Each name has its own cache, request lifecycle, and `AdEvent.placementId`. Rewarded and manual App Open placements use `FullscreenPlacement.rewarded` / `.appOpen` with `AdMobKit.rewardedFor(id)` / `AdMobKit.appOpenFor(id)`. Automatic resume continues to use the default `AdMobKit.appOpen`. The library primes registered placements when ads are allowed; register only likely opportunities, because every distinct unit can make a request. Registering the same configuration again does nothing; supplying new IDs for a name invalidates its old ad without disturbing other placements. Call `AdMobKit.unregisterFullscreenPlacement(AdFormat.interstitial, 'settings')` when a dynamic placement is removed. Premium and consent changes clear all caches. Test mode substitutes Google's official unit IDs on each platform.

Fullscreen SDK load attempts share a library-owned FIFO queue with two active request slots. The default App Open request enters first; named placements follow registration order. A slot is released by its SDK callback, or after 20 seconds if that callback stalls, so later placements can still load. A stalled native request itself is not duplicated; the watchdog may temporarily allow more than two native requests in flight after a timeout. App Open, interstitial and rewarded presentation still share one fullscreen lock.

For a splash or another flow that deliberately waits, call `await AdMobKit.appOpen.waitUntilReady()` before `show(true)`. The default wait limit is `AdMobConfig.adReadinessTimeout` (12 seconds); override one opportunity with `waitUntilReady(timeout: const Duration(seconds: 5))`. A `false` result means the ad was unavailable before the deadline. The underlying SDK request continues and its late result can serve a later opportunity; it never appears automatically. Consent UI and SDK initialization are outside this timer. Normal navigation should use cached ads immediately and should not await readiness.

If an ad-unit change happens during a native fullscreen request, the replacement waits for that request to settle. Callers waiting for the replacement share one future; cancellation, eligibility invalidation, or manager disposal settles them without starting overlapping requests.

Failures retry at **30, 60, and 120 seconds**, with one timer. After exhaustion, automatic retries stop; fullscreen opportunities cannot start a new cycle for five minutes. Disposal, entitlement, and consent/config invalidation cancel retries. No watchdog starts a second request merely because a native load is slow. An invalidated fullscreen request must settle before a replacement is issued.

Interstitial/rewarded cache age is capped at one hour and App Open at four hours; shorter configured values are supported. Expiry is checked on use. There is no continuous expiry refresh timer.

### Delivery diagnostics

`AdMobKit.addEventListener(listener)` is optional and local. `AdEventType.request`, `loaded`, `loadFailed`, `cacheHit`, `cacheMiss`, `opportunity`, `presentationAccepted`, `presentationFailed`, `impression`, `dismissed`, `expired`, `invalidated`, `waitTimedOut`, and `skipped` help trace the fullscreen path. `AdEvent.reason` explains skips such as background state, cooldown, active fullscreen presentation, or unavailable cache. Banner/native preload events cover requests, loads, failures, cache handoff and SDK impressions; `loadFailed.errorMessage` contains the SDK error when available, while `reason == 'load_timeout'` identifies an unanswered request. A native `skipped` event with `reason == 'factory_registration_failed'` identifies a template setup error before an ad request. Keep listeners lightweight and remove them with `removeEventListener` when no longer needed. Only the SDK `impression` callback confirms an impression; `presentationAccepted` is not a substitute.

When the Google Mobile Ads SDK supplies impression-level revenue, every format also emits `AdEventType.paid` with `valueMicros`, `currencyCode`, and `precision`. For example, `valueMicros / 1000000` converts to the reported currency unit. This is an SDK estimate, not a guaranteed payout; the callback may be unavailable for an account or impression. The library keeps the event local so the app can choose its own analytics destination. Never count a paid event as an extra impression.

Calculate a **client load-success proxy** as loaded requests / completed requests; use AdMob reporting for its exact request match rate. Calculate **loaded-ad show rate at eligible opportunities** as accepted presentations / `cacheHit` events whose `reason` is `presentation`, **SDK impression rate** as SDK impressions / accepted presentations, and **impressions per eligible session** as SDK impressions / eligible sessions. Segment by format, `AdEvent.placementId`, platform, consent state and network. The 90%+ target applies only to the second ratio; inventory, user flow and network can still limit every metric. Do not count a cache hit whose reason is `preload` as a presentation opportunity. App code should log session identifiers separately if those cuts are needed.

The [delivery audit and real-device test procedure](doc/DELIVERY_AUDIT.md) lists the main non-impression paths and a test-ad checklist for both platforms.

## App Open

With `autoResumeAppOpen: true`, a real background-to-foreground transition can show a ready ad, subject to consent, entitlement, foreground state, cooldown, paywall suppression, freshness, and the fullscreen mutex. Cold-start resume does not show an ad. Background transitions caused by an already-presented fullscreen ad do not trigger another App Open ad.

```dart
await AdMobKit.appOpen.show(true); // Optional manual opportunity.
```

Place App Open opportunities around loading/return experiences, following [Google's placement guidance](https://developers.google.com/admob/flutter/app-open). The SDK cannot determine whether every host screen is an appropriate ad placement.

## Native layout update in 4.0.1

After upgrading from 4.0.0, rebuild the native app to use the updated bundled
layouts; hot reload is insufficient for native code changes.

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
const NativeAdWidget.bigNative(); // Large splash card; default height 280.
```

### Library-managed preload

Applications only place `BannerAdWidget` and `NativeAdWidget`; they do not create preload controllers or call `preload()`. After initialization and consent, the library warms one default `bigNative`, one default `mediumNative`, and one `large` banner when their ad unit IDs are configured. A widget takes the matching ready ad and the library prepares one replacement for a later visit. Each ad belongs to exactly one visible widget. An in-flight request is shared, so the widget shows its normal loading placeholder until the SDK responds.

Other banner sizes, adaptive widths, native `small`, custom styles, and per-widget ad-unit overrides are learned on first use and then cached by their exact format. A first visit to one of those placements may load visibly: the library cannot know its width or style before the widget exists. Cache entries expire after two minutes unused; pending requests time out after one minute. Entitlement, consent and ad-unit changes clear unused ads. The older controller API remains available for source compatibility but is no longer needed for normal integration.

Preloading cannot guarantee match rate, show rate, or CTR; those also depend on inventory and user behavior. Automatic warm requests for screens never visited can lower show rate, so measure actual AdMob reports and adjust placements accordingly. SDK impression/click callbacks remain the source of events. See [AdMob metric definitions](https://support.google.com/admob/table/9462111?hl=en).

The library limits concurrent **fullscreen** SDK load attempts to two. Banner
and native loads are independent: initialization can also warm one large banner
and one ad per default native template at the same time. This limit controls
request scheduling, not AdMob fill or impression rates.

Native templates default to a white background and a 10dp/pt CTA corner radius. `bigNative` is the large splash card with full-width square-corner media, a 52dp icon, headline/body, AdChoices, optional SDK rating/store assets, and a full-width CTA. It defaults to 280 logical pixels on both platforms. `mediumNative` is a horizontal card that defaults to 128dp: fixed 120×120dp media at the top left and headline, advertiser, optional body, AdChoices and CTA on the right. Both platforms use bundled layouts that keep the supplied media/header/CTA structure and developer colors. Optional body copy is hidden when the card cannot show its first 90 characters without truncation; the `bigNative` headline keeps up to three lines, while `mediumNative` keeps one line as supplied. Missing optional assets collapse cleanly. The compact `small` template still uses Google's official template.

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
native card and its horizontal loading skeleton. Heights below 128 are raised
to 128 so video media remains at least 120×120dp/pt; larger heights are
respected. Optional copy yields space on compact cards. Keep ad assets readable
at the chosen size.

The widget uses the library-owned cache automatically. It never shares the same
loaded native view between two visible placements.

Both bundled Android factories register once per Flutter engine before a custom native request. No `MainActivity` changes or manual registration are required. Native SDK asset registration retains click/impression tracking and AdChoices. The former `NativeAdWidget.medium()` constructor remains as a deprecated compatibility alias for `bigNative()`.

Stable widget rebuilds do not request again. Adaptive banners reload on a real available-width change. Inline adaptive banners use the container width and the actual SDK height after loading; 50dp and 250dp are default maximums, not guaranteed creative heights. Use them in scrolling content. Changing width or the height cap requests the new size once. `fitToWidth: true` uses a proportional `FittedBox`: a 300×250 rectangle rendered at 360dp width occupies 300dp height. `large` and `mediumRectangle` enable this by default; set `fitToWidth: false` to retain their native 320×100 and 300×250 sizes respectively. Inline/anchored adaptive constructors fill the available width using SDK sizing, without scaling by default. See [inline adaptive sizing](https://developers.google.com/admob/flutter/banner/inline-adaptive). Reserve sufficient space and keep ads away from navigation/tap targets. Native templates require a bounded width of at least 320 logical pixels; test both platforms and text sizes. Big and small template heights retain their minimums; `mediumNative` respects heights of 128dp or more so its video MediaView stays at least 120×120dp. See [Google's native-ad guidance](https://support.google.com/admob/answer/6329638).

Each mounted placement owns its native resource, including while loading. Separate visible placements legitimately request separate ads; an `AdWidget` cannot share one native view across placements. Widget retries are bounded to three and cancelled on unmount or invalidation. Successful banners may refresh according to AdMob's SDK/server settings; the wrapper does not add a success refresh loop. Keep stable widget keys to preserve placement resources.

## Premium and configuration

```dart
AdMobKit.setEntitled(true);  // Works before or after initialize.
AdMobKit.setEntitled(false); // Eligible automatic preloads may resume.

AdMobKit.updateConfig(AdMobKit.config.copyWith(testMode: true));
```

Entitlement is stored centrally. Cached resources are invalidated and inline placements collapse. Native network work already submitted cannot be recalled; late results are discarded. An already-presented fullscreen ad retains its exact lease until it closes. Changing configuration never forcibly disposes that presentation or releases its lease early. `updateConfig` preserves an active premium entitlement even if the supplied config has the default `isEntitled: false`; use `setEntitled(false)` explicitly after verifying the user is no longer premium.

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

Use `AdMobKit.addEventListener(listener)` and `removeEventListener(listener)` for optional local lifecycle observation. Banner/native impression, click, and paid-value events are forwarded from SDK callbacks. No event data is transmitted externally by this package, and no revenue is inferred from load/show calls.

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

The bundled iOS native layouts support both Swift Package Manager (Flutter 3.44+)
and CocoaPods. The host app still needs the `google_mobile_ads` iOS app ID
configuration described above.

If your iOS CocoaPods app uses `use_frameworks!`, pin
`google_mobile_ads: 9.0.0` directly in the host app until the 9.1.0 non-modular
`GoogleMobileAds_Beta.h` regression is fixed. A fresh consumer app built with
9.0.0 and frameworks enabled; 9.1.0 failed in that configuration. Apps that
require 9.1.0 remain compatible with this package, but should use Swift Package
Manager or resolve the upstream CocoaPods issue. See the
[upstream google_mobile_ads issue](https://github.com/googleads/googleads-mobile-flutter/issues/1472).

Verified with Flutter 3.44.1 and Dart 3.12.1: 194 automated tests passed locally and static analysis passed. Android debug APK and iOS simulator builds passed in a [verified CI run](https://github.com/AmeerHamza-9902/flutter_admob_kit/actions/runs/37954752074). Both example home screens rendered in the earlier smoke run; an iOS test banner rendered. Android returned a no-fill response during that smoke run. Live consent configuration, all-format device testing and network recovery still need host verification; see the [technical audit](doc/FINAL_AUDIT.md).

## Migration from 3.x

- Remove any `preloadController` arguments from banner/native widgets. Their
  matching ready or in-flight ads are now managed by the library automatically.
- UMP flow defaults to enabled; disabling it no longer bypasses the shared gate.
- SDK initialization failures propagate instead of being silently ignored.
- Removed ownership-less `tryAcquire`/`release`; advanced mutex users must retain the token from `acquireToken` and use `releaseWithToken`.
- Raised minimum Flutter/Dart/plugin requirements to the verified API baseline.
- Medium rectangles no longer scale their native creative.
- Use the central facade rather than constructing independent managers for the same unit.
- Removed the unused `AdMobKit.instance` alias and ignored `PaywallCloseGuard.adUnitId` parameter; use static APIs and central configuration.

## License

MIT. See [LICENSE](LICENSE).
