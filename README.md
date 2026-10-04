# flutter_admob_kit

[![pub version](https://img.shields.io/pub/v/flutter_admob_kit.svg)](https://pub.dev/packages/flutter_admob_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-green.svg)]()

A lightweight, production-ready internal AdMob SDK for Flutter. Built on Google Mobile Ads, designed for minimal configuration, zero boilerplate, and optimal ad fill, show, and match rates.

---

## 💡 Why `flutter_admob_kit`?

* ⚡ **Zero-Boilerplate API:** Show ads with `AdMobKit.interstitial.show(true)` or `show(false)` (clean boolean flag pass-through).
* 🛡️ **Zero Waste / Spam Protection:** Calling `show(false)` makes zero ad requests and avoids hidden loops, protecting your AdMob account and match rate.
* 📦 **Minimal Dependencies:** Zero bloated dependencies. Only `google_mobile_ads` is required.
* 🔄 **Automatic Background Preloading:** Automatically preloads the next fullscreen ad upon dismissal or initialization.
* ⏱️ **Ad Freshness & Expiry Guard:** Auto-evicts expired ads (4 hrs for App Open, Interstitial, and Rewarded) so stale impressions never occur.
* 🔒 **Fullscreen Presentation Mutex:** Guarantees that only one fullscreen ad (App Open, Interstitial, or Rewarded) presents at any given moment.
* 📱 **Native App Lifecycle Observer:** Automatically handles App Open ads on resume transitions without manual `WidgetsBindingObserver` boilerplate.
* 💎 **Instant Global Entitlement Gate (`setEntitled`):** Instantly suppresses all fullscreen ads and collapses banner/native widgets to zero height for premium users.
* 🛡️ **Paywall Close Guard:** Protects back gestures and close buttons during paywalls without trapping users or triggering unexpected App Open ads.
* 🎨 **Out-of-the-Box Native Templates:** Built-in small and medium Native templates—no native Android XML or iOS XIB files needed.

---

## 📦 Installation

```yaml
dependencies:
  flutter_admob_kit: ^4.0.0
```

---

## 🚀 Quick Start in 3 Easy Steps

### 1. Initialize Once in `main.dart`

Configure your Ad Unit IDs once. The SDK automatically selects the appropriate Android or iOS ID at runtime:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdMobKit.initialize(
    config: const AdMobConfig(
      android: AdPlatformConfig(
        interstitial: 'ca-app-pub-XXXX/XXXX',
        rewarded: 'ca-app-pub-XXXX/XXXX',
        appOpen: 'ca-app-pub-XXXX/XXXX',
        banner: 'ca-app-pub-XXXX/XXXX',
        native: 'ca-app-pub-XXXX/XXXX',
      ),
      ios: AdPlatformConfig(
        interstitial: 'ca-app-pub-XXXX/XXXX',
        rewarded: 'ca-app-pub-XXXX/XXXX',
        appOpen: 'ca-app-pub-XXXX/XXXX',
        banner: 'ca-app-pub-XXXX/XXXX',
        native: 'ca-app-pub-XXXX/XXXX',
      ),
      autoResumeAppOpen: true, // Shows App Open ad on app resume automatically
    ),
  );

  runApp(const MyApp());
}
```

### 2. Show Fullscreen Ads (Controlled via Boolean Flag)

Pass your boolean flag directly to `show()`:

```dart
// Interstitial
final bool showAd = true; // or your app's logic/toggle
final bool wasShown = await AdMobKit.interstitial.show(showAd);

// Rewarded
await AdMobKit.rewarded.show(
  true,
  onReward: (reward) {
    print('User earned: ${reward.amount} ${reward.type}');
  },
);

// App Open (if manual presentation is needed)
await AdMobKit.appOpen.show(true);
```

> **Note:** If `false` is passed, no ad is presented and no new ad request is triggered. If `true` is passed, the preloaded ad is displayed immediately, and the next ad is preloaded in the background.

### 3. Add Banner & Native Widgets to UI

```dart
// 1. Small Adaptive Banner (Full width on Android & iOS):
const BannerAdWidget.small();

// 2. Medium Rectangle Banner (300x250) fitted seamlessly to full width:
const BannerAdWidget.mediumRectangle();

// 3. Compact Small Native Ad (90dp) — Icon + Headline + CTA:
const NativeAdWidget.small();

// 4. Medium Native Card (320dp) — Top Media + Icon + Headline + Body + CTA:
const NativeAdWidget.medium();

// 5. Fully Customizable Styling (Colors, CTA button, Background):
NativeAdWidget.medium(
  style: const NativeAdStyle(
    backgroundColor: Colors.white,
    callToActionColor: Color(0xFF066136),
    callToActionTextColor: Colors.white,
    primaryTextColor: Color(0xFF0E1A14),
    secondaryTextColor: Color(0xFF55655D),
    cornerRadius: 8.0,
  ),
);
```

---

## 🛡️ Paywall Close Guard

Intercepts back navigation and close buttons on subscription/paywall screens. Displays an interstitial ad upon closing (if available), but **never traps the user** if ad loading fails or times out:

```dart
PaywallCloseGuard(
  isEntitled: user.isPremium, // Bypasses ads completely for paid users
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

## 💎 Instant Premium Suppression

When a user purchases an in-app purchase or subscription:

```dart
// Instantly silences all ads across the entire app:
AdMobKit.setEntitled(true);
```

Banners and native widgets will automatically collapse to `SizedBox.shrink()` without leaving blank spaces or artifacts.

---

## 🔒 GDPR / UMP Consent & Privacy Options

Google UMP (User Messaging Platform) consent is handled automatically during initialization when `enableUmpConsent: true` is configured.

To allow users to change their privacy / consent choices later (e.g. from your App Settings screen):

```dart
// Opens Google's Privacy Options form:
final bool updated = await AdMobKit.showPrivacyConsentForm();
```

---

## 📄 License

MIT © [Ameerhamza-tech](https://github.com/Ameerhamza-tech)