# flutter_admob_kit

[![pub version](https://img.shields.io/pub/v/flutter_admob_kit.svg)](https://pub.dev/packages/flutter_admob_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-green.svg)]()

A production-ready, **config-driven AdMob library** for Flutter.

Manage all your ads from a single JSON config — loaded from **Firebase Remote Config** (with local asset fallback). No more scattered ad unit IDs across your codebase.

---

## ✨ Features

- 🎯 **Config-driven** — one JSON controls all ads across all screens
- 🔥 **Firebase Remote Config** — update ad units & enable/disable ads without an app update
- 📦 **Local fallback** — works offline with a bundled `ads_config.json`
- ⚡ **Click threshold** — show interstitials after N clicks automatically
- 🖼️ **Drop-in widgets** — `BannerAdWidget` and `NativeAdWidget` in one line
- 🚀 **App Open ads** — splash + on-resume, fully managed
- 🔄 **Ad preloading** — ads are cached in background for instant display

---

## 📦 Installation

```yaml
dependencies:
  flutter_admob_kit: ^1.0.0
```

```bash
flutter pub get
```

---

## 🚀 Quick Start

### 1. Add your config file

Create `assets/ads_config.json`:

```json
{
  "Interstitial_btm_nav": {
    "adUnit": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
    "click_threshold": 3,
    "show": true
  },
  "ProCloseInterstitial": {
    "adUnit": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
    "show": true
  },
  "click_interstitial": {
    "ad_unit_id": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
    "is_enabled": true,
    "click_threshold": 3
  },
  "SplashInterstitial": {
    "adUnit": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
    "show": true
  },
  "SplashAppOpen": {
    "adUnit": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
    "show": true
  },
  "OnResumeAppOpen": {
    "adUnit": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
    "show": true
  },
  "Screens": {
    "home_screen": {
      "native_id": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
      "native_ads": true,
      "banner_id": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
      "banner_ads": true
    },
    "setting_screen": {
      "native_id": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
      "native_ads": true,
      "banner_id": "ca-app-pub-XXXXXXXX/XXXXXXXXXX",
      "banner_ads": false
    }
  }
}
```

Register it in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/ads_config.json
```

### 2. Initialize in `main.dart`

```dart
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FlutterAdmobKit.instance.init(); // Firebase → local fallback
  runApp(const MyApp());
}
```

---

## 📱 Usage

### Interstitial Ads

```dart
// Bottom navigation tap
AdMobKit.instance.onBottomNavClick(context);

// Any general click (button, list item, etc.)
FlutterAdmobKit.instance.onGeneralClick(context);

// Pro/Premium screen close
await FlutterAdmobKit.instance.showProCloseInterstitial(context);

// Splash screen interstitial
await FlutterAdmobKit.instance.showSplashInterstitial(context);
```

### App Open Ads

```dart
// In SplashScreen
@override
void initState() {
  super.initState();
  FlutterAdmobKit.instance.showSplashAppOpen().then((_) {
    Navigator.pushReplacementNamed(context, '/home');
  });
}
```

### Banner Widget

```dart
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      Expanded(child: YourContent()),
      BannerAdWidget(screenKey: 'home_screen'), // checks config automatically
    ],
  );
}
```

### Native Ad Widget

```dart
NativeAdWidget(screenKey: 'home_screen')
NativeAdWidget(screenKey: 'splash_screen', height: 80)
```

### Check ad status at runtime

```dart
final kit = FlutterAdmobKit.instance;

if (kit.isBannerEnabled('home_screen')) { ... }
if (kit.isNativeEnabled('setting_screen')) { ... }

final config = kit.screenConfig('home_screen');
print(config.bannerId);
```

---

## 🔥 Firebase Remote Config (optional)

To control ads remotely without an app update:

1. Go to **Firebase Console → Remote Config**
2. Add a new parameter with key: `ads_config`
3. Paste your full JSON as the value
4. Publish changes

The library fetches it automatically on every app launch. If fetch fails, it falls back to your local `assets/ads_config.json`.

---

## 🧪 Test Ad Unit IDs

Use these during development:

| Format | Test ID |
|--------|---------|
| App Open | `ca-app-pub-3940256099942544/9257395921` |
| Interstitial | `ca-app-pub-3940256099942544/1033173712` |
| Banner | `ca-app-pub-3940256099942544/6300978111` |
| Native | `ca-app-pub-3940256099942544/2247696110` |

---

## 📋 Config Schema

| Key | Fields | Description |
|-----|--------|-------------|
| `Interstitial_btm_nav` | `adUnit`, `click_threshold`, `show` | Bottom nav interstitial |
| `ProCloseInterstitial` | `adUnit`, `show` | Pro screen close interstitial |
| `click_interstitial` | `ad_unit_id`, `is_enabled`, `click_threshold` | General click interstitial |
| `SplashInterstitial` | `adUnit`, `show` | Splash interstitial |
| `SplashAppOpen` | `adUnit`, `show` | Splash app open ad |
| `OnResumeAppOpen` | `adUnit`, `show` | On-resume app open ad |
| `Screens` | per-screen config | Banner + Native per screen |

---

## 🤝 Contributing

PRs welcome! Please open an issue first to discuss what you'd like to change.

---

## 📄 License

MIT © [Ameerhamza-tech](https://github.com/Ameerhamza-tech)
