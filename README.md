# flutter_admob_kit

[![pub version](https://img.shields.io/pub/v/flutter_admob_kit.svg)](https://pub.dev/packages/flutter_admob_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-green.svg)]()

Production-ready, deterministic Google AdMob package for Flutter with JSON Remote Config, zero Cumulative Layout Shift (CLS) shimmer placeholders, Paywall close guards, automatic App Open resume lifecycles, and concurrency leasing.

---

## ✨ Why flutter_admob_kit?

* ⚡ **1-Line Setup & Preloading:** Initialize with local JSON or Firebase Remote Config in seconds.
* 💎 **Global Entitlement Gate (`setEntitled`):** 1-line instant suppression of all ads across the app for paid/premium users.
* 🛡️ **Paywall Close Guard (`PaywallCloseGuard`):** Hardware back-button & close-button protection (zero ads for paid users, zero trapped users).
* 🔒 **Presentation Mutex Coordinator:** Prevents overlapping full-screen ads across all formats.
* 📈 **High Show Rate & Match Rate:** Non-destructive click counter preserves progression until ad is actually presented; automatic in-memory preloading prevents unserved requests.
* 🎨 **Zero-CLS Shimmer Placeholders:** Built-in animated skeletons for Banner and Native ads.
* 🔄 **Auto Resume App Open:** 1-line automatic foreground App Open ad listener.
* ⏱️ **Ad Freshness & Auto-Eviction:** Automatically discards expired ads (1h/4h) to avoid low show rate.
* 🪙 **Rewarded Ads & Coin Tracking:** Simple coin management with `ListenableBuilder`.

---

## 📦 Installation

```yaml
dependencies:
  flutter_admob_kit: ^4.0.0
```

---

## 🚀 Quick Start in 3 Easy Steps

### 1. Initialize in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize with JSON asset or Firebase Remote Config
  await AdMobKit.instance.init(localAsset: 'assets/ads_config.json');

  // (Optional) Enable 1-line automatic App Open ad on app resume
  AdMobKit.instance.enableAutoResumeAppOpen();

  runApp(const MyApp());
}
```

### 2. Drop-in Banner & Native Ads with Shimmer

```dart
// Zero setup — resolves automatically from your screen JSON config!
BannerAdWidget(
  screenKey: 'home_screen',
  showShimmer: true, // Smooth zero-shift placeholder
)

// Or Native ad card
NativeAdWidget(
  screenKey: 'home_screen',
  height: 300,
  showShimmer: true,
)
```

### 3. Bulletproof Paywall Close Guard

```dart
PaywallCloseGuard(
  adUnitId: 'ca-app-pub-XXXX/XXXX',
  isEntitled: user.isPremium, // Bypasses ads if user purchased
  onDismiss: () => Navigator.of(context).pop(),
  child: Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => PaywallCloseGuard.dismiss(context),
      ),
    ),
    body: PaywallBody(),
  ),
)
```

---

## 📱 Fullscreen Ads & Click Counter

### Interstitial on Button or Tab Click (Every N taps)
```dart
// Automatically counts clicks and shows ad when threshold is reached
AdMobKit.instance.onBottomNavClick(context);
AdMobKit.instance.onGeneralClick(context);
```

### Direct Interstitial Ad
```dart
final vm = InterstitialAdManager();
await vm.loadAd('ca-app-pub-XXXX/XXXX');
vm.showAd();
```

### Rewarded Ad (With Coins)
```dart
final vm = RewardedAdManager();
vm.onCoinsEarned = (coins) => print('Total coins: $coins');
await vm.loadAd('ca-app-pub-XXXX/XXXX');
vm.showAd();

// In UI:
ListenableBuilder(
  listenable: vm,
  builder: (_, __) => Text('Coins: ${vm.coins}'),
);
```

---

## ☁️ Firebase Remote Config Integration

When new remote config is fetched from Firebase, simply update AdMobKit:

```dart
final remoteJson = json.decode(FirebaseRemoteConfig.instance.getString('ads_config'));
AdMobKit.instance.updateConfigFromJson(remoteJson);
```
All banner and native ads currently on screen will **automatically reload and adapt dynamically**!

---

## 💎 Global Entitlement Gate (Paid Users)

When a user purchases a subscription or unlocks an ad-free tier, suppress all ads across the app in one line:

```dart
// All ads (banner, native, interstitial, app open) are suppressed instantly
AdMobKit.instance.setEntitled(true);
```
Currently mounted banner and native ads will immediately collapse to zero height without leaving visual artifacts.

---

## 📋 Standard Remote Config JSON Format

```json
{
  "is_entitled": false,
  "interstitial_btm_nav": {
    "ad_unit_id": "ca-app-pub-3940256099942544/1033173712",
    "click_threshold": 3,
    "is_enabled": true
  },
  "click_interstitial": {
    "ad_unit_id": "ca-app-pub-3940256099942544/1033173712",
    "click_threshold": 3,
    "is_enabled": true
  },
  "pro_close_interstitial": {
    "ad_unit_id": "ca-app-pub-3940256099942544/1033173712",
    "is_enabled": true
  },
  "splash_app_open": {
    "ad_unit_id": "ca-app-pub-3940256099942544/9257395921",
    "is_enabled": true
  },
  "on_resume_app_open": {
    "ad_unit_id": "ca-app-pub-3940256099942544/9257395921",
    "is_enabled": true
  },
  "screens": {
    "home_screen": {
      "banner_id": "ca-app-pub-3940256099942544/6300978111",
      "banner_ads": true,
      "native_id": "ca-app-pub-3940256099942544/2247696110",
      "native_ads": true
    }
  }
}
```

*(Note: Legacy camelCase keys such as `Interstitial_btm_nav`, `SplashAppOpen`, `Screens` are also fully supported for backward compatibility).*

---

## 📄 License

MIT © [Ameerhamza-tech](https://github.com/Ameerhamza-tech)