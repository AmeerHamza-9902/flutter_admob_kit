# flutter_admob_kit

[![pub version](https://img.shields.io/pub/v/flutter_admob_kit.svg)](https://pub.dev/packages/flutter_admob_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-green.svg)]()

A lightweight, robust, production-ready Google Mobile Ads wrapper for Flutter. Designed to behave like a small internal AdMob SDK: minimal setup, zero boilerplate, optimal Match/Show rates, and zero unnecessary ad requests.

---

## 🌟 Key Features

* ⚡ **Simple & Declarative API:** Show ads with `AdMobKit.interstitial.show(true)` or `show(false)`.
* 🛡️ **Zero-Spam & Zero-Waste:** Calling `show(false)` is a 100% no-op. It triggers zero network requests and does not reset or reload ads.
* 📦 **Zero External Bloat:** Pure Dart configuration. No external servers or configuration bloat. Only `google_mobile_ads` is used.
* 🔒 **GDPR & UMP Consent Gating:** Integrated Google User Messaging Platform (UMP). Ads are gated and will **never** request or preload until `canRequestAds()` reports safe consent.
* 🔄 **Automatic Single-Pool Preload:** Automatically preloads the next fullscreen ad in the background after dismissal.
* ⏱️ **Ad Freshness & Expiry (4 Hours):** Stale ads are automatically evicted and refreshed so invalid impressions never occur.
* 🛡️ **Token-Based Fullscreen Mutex:** Strict mutual exclusion ensures Interstitial, Rewarded, and App Open ads never overlap or collide.
* 📱 **Native App Open Lifecycle:** Automatically shows App Open ads when returning from background, with cold-start / first-launch protection and cooldown checks.
* 💎 **Instant Global Entitlement Gate (`setEntitled`):** Instantly suppresses all ads and collapses Banner and Native widgets to zero height when users purchase premium.
* 🎨 **Google Official Native Templates:** Out-of-the-box support for `small` (90dp) and `medium` (320dp) native ads without touching Android XML or iOS XIB files.
* 📐 **Zero-CLS Responsive Banners:** Full-width Anchored Adaptive Banners and 300x250 Medium Rectangles with built-in zero Cumulative Layout Shift (CLS) shimmer skeletons.

---

## 📦 Installation

Add `flutter_admob_kit` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_admob_kit: ^4.0.0
```

---

## 🚀 Complete Usage Guide

### 1. Initialize in `main.dart`

Configure your Ad Unit IDs once during app launch. The SDK automatically selects the appropriate Android or iOS ID:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdMobKit.initialize(
    config: const AdMobConfig(
      // Android Ad Unit IDs
      android: AdPlatformConfig(
        interstitial: 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY',
        rewarded: 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY',
        appOpen: 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY',
        banner: 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY',
        native: 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY',
      ),
      // iOS Ad Unit IDs
      ios: AdPlatformConfig(
        interstitial: 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ',
        rewarded: 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ',
        appOpen: 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ',
        banner: 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ',
        native: 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ',
      ),
      testMode: false,           // Set to true to automatically use official Google test IDs during development
      enableUmpConsent: true,    // Checks and presents Google UMP GDPR consent form
      autoResumeAppOpen: true,   // Automatically shows App Open ad when returning from background
      interstitialCooldown: Duration(seconds: 30), // Minimum interval between interstitials
      appOpenCooldown: Duration(seconds: 15),       // Minimum interval between App Open ads
    ),
  );

  runApp(const MyApp());
}
```

---

### 2. Interstitial Ads

Trigger interstitial ads during screen transitions or button clicks:

```dart
// To show an ad (e.g. user completes a level or navigates):
final bool wasShown = await AdMobKit.interstitial.show(true);

// If user is non-ad or condition is not met (pass false):
// Complete NO-OP: No ad is shown and zero network requests are made.
await AdMobKit.interstitial.show(false);
```

---

### 3. Rewarded Ads

Present rewarded video ads and grant rewards safely (reward callback is guaranteed to fire at most once):

```dart
await AdMobKit.rewarded.show(
  true,
  onReward: (RewardItem reward) {
    // Grant coins, gems, or unlock features for the user:
    print('User earned: ${reward.amount} ${reward.type}');
  },
);
```

---

### 4. App Open Ads

* **Automatic Lifecycle:** If `autoResumeAppOpen: true` is configured in `AdMobKit.initialize()`, App Open ads display automatically when the app resumes from the background.
* **Manual Display:** If you need to trigger an App Open ad manually at a custom point:
  ```dart
  await AdMobKit.appOpen.show(true);
  ```

---

### 5. Banner Ads

Drop-in banner widgets with zero Cumulative Layout Shift (CLS):

```dart
// 1. Small Anchored Adaptive Banner (Automatically matches device width):
const BannerAdWidget.small()

// 2. Medium Rectangle Banner (300x250 - ideal for feeds and scroll views):
const BannerAdWidget.mediumRectangle()
```

#### Example inside a Scaffold:
```dart
Scaffold(
  appBar: AppBar(title: const Text('My App')),
  body: const Center(child: Text('Content')),
  bottomNavigationBar: const SafeArea(
    child: BannerAdWidget.small(),
  ),
);
```

---

### 6. Native Ads

Pre-built, policy-compliant native ad layouts that blend seamlessly with Flutter widgets:

```dart
// 1. Small Compact Native Row (Height: 90dp - perfect for ListView rows):
const NativeAdWidget.small()

// 2. Medium Native Card (Height: 320dp - full media view + headline + body + CTA):
const NativeAdWidget.medium()

// 3. Fully Customized Visual Styling:
NativeAdWidget.medium(
  style: const NativeAdStyle(
    backgroundColor: Colors.white,
    cornerRadius: 12.0,
    callToActionColor: Color(0xFF1E88E5),
    callToActionTextColor: Colors.white,
    primaryTextColor: Color(0xFF212121),
    secondaryTextColor: Color(0xFF757575),
  ),
)
```

---

### 7. GDPR / UMP Consent & Privacy Options

* **Automatic Flow:** Set `enableUmpConsent: true` during initialization. If the user is in the EU/UK/EEA, the consent dialog will automatically appear on startup.
* **Privacy Options Form:** Allow users to update their consent choices anytime from your App Settings screen:

```dart
ListTile(
  leading: const Icon(Icons.privacy_tip_outlined),
  title: const Text('Privacy & Consent Choices'),
  onTap: () async {
    final bool updated = await AdMobKit.showPrivacyConsentForm();
    if (updated) {
      debugPrint('Consent preferences updated by user');
    }
  },
);
```

---

### 8. Premium / In-App Purchases (`setEntitled`)

When a user purchases a subscription or ad removal in-app purchase:

```dart
// Suppress all ads across the app immediately:
AdMobKit.setEntitled(true);
```

* All cached fullscreen ads are immediately evicted from memory.
* Any active Banner and Native widgets automatically collapse to `SizedBox.shrink()`.
* All future ad requests and preloads are cancelled.

---

### 9. Paywall Close Guard

Prevent users from accidentally triggering App Open ads or getting trapped by ads when dismissing a paywall or subscription screen:

```dart
PaywallCloseGuard(
  isEntitled: user.isPremium,
  onDismiss: () => Navigator.of(context).pop(),
  child: Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => PaywallCloseGuard.dismiss(context),
      ),
    ),
    body: const PaywallBody(),
  ),
)
```

---

### 10. Dynamic Configuration (`updateConfig`)

Update ad unit IDs or test mode dynamically at runtime. Old cached ads and in-flight retries are immediately invalidated and safely evicted:

```dart
// Switch to test mode or update Ad Unit IDs dynamically:
AdMobKit.updateConfig(
  AdMobKit.config.copyWith(
    testMode: true,
  ),
);
```

---

## 📈 Match Rate & Show Rate Optimization

| Feature | How It Protects Your Account & Metrics |
|---|---|
| **Deduplicated Preloads** | Preloads exactly 1 ad per format. Rapid clicks or rebuilds will never trigger duplicate ad requests. |
| **Idempotent `show(false)`** | Zero requests are made when `false` is passed, keeping your Match Rate clean. |
| **Freshness Protection** | Discards stale ads after 4 hours to comply with Google AdMob policy and ensure impressions count. |
| **Ownership Mutex** | Guarantees that Interstitial, Rewarded, and App Open ads never collide. |

---

## 📄 License

MIT © [Ameerhamza-tech](https://github.com/Ameerhamza-tech)