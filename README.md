# flutter_admob_kit

[![pub version](https://img.shields.io/pub/v/flutter_admob_kit.svg)](https://pub.dev/packages/flutter_admob_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-green.svg)]()

Same ViewModel pattern. Same callbacks. Same `isInProScreen` guard. Just Flutter.

---

## ✨ Features

| Feature | Details |
|---------|---------|
| 📺 **All ad formats** | Banner, Interstitial, Rewarded, Rewarded Interstitial, App Open, Native |
| 🔄 **Auto retry** | Retries failed loads up to 3 times (2s, 4s, 6s backoff) |
| ⏱️ **Expiry handling** | Discards stale ads automatically — no more black screens |
| 🪙 **Coin tracking** | `coins` property with `onCoinsEarned` callback |
| 🛡️ **Paywall guard** | `AppOpenAdManager.isInProScreen` prevents ads on purchase screens |
| 🔁 **Click threshold** | Show interstitial after N clicks automatically |

---

## 📦 Installation

```yaml
dependencies:
  flutter_admob_kit: ^3.0.2
```

```bash
flutter pub get
```

---

## 🚀 Setup

Initialize once in `main.dart`:

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}
```

---

## 📱 Usage

### Banner Ad

```dart
// Swift: BannerAdView(AdUnitID: "...", adLoadFailed: $failed)
BannerAdWidget(
  adUnitId: 'ca-app-pub-XXXX/XXXX',
  onAdLoadFailed: () => setState(() => _showBanner = false),
)
```

---

### Interstitial Ad

```dart
// Swift: @StateObject var interstitialVM = InterstitialViewModel()
final _vm = InterstitialAdManager();

@override
void initState() {
  super.initState();
  _vm.onAdLoadComplete = () => print('Ad loaded!');
  _vm.onAdDismissed   = () => Navigator.pushNamed(context, '/home');
  _vm.loadAd('ca-app-pub-XXXX/XXXX');
}

// Show immediately
_vm.showAd();

// Show after N clicks (bottom nav, general buttons)
_vm.onClickEvent('ca-app-pub-XXXX/XXXX', threshold: 3);

@override
void dispose() {
  _vm.dispose();
  super.dispose();
}
```

---

### App Open Ad

```dart
// Swift: @StateObject var appOpenVM = AppOpenAdManager()
final _appOpenVM = AppOpenAdManager();

@override
void initState() {
  super.initState();
  _appOpenVM.onAdDismissed = () => widget.onFinish();
  _appOpenVM.loadAd('ca-app-pub-XXXX/XXXX').then((_) {
    _appOpenVM.showAdIfAvailable('ca-app-pub-XXXX/XXXX');
  });
}

@override
void dispose() {
  _appOpenVM.dispose();
  super.dispose();
}
```

**Prevent on paywall — same as Swift:**
```dart
@override
void initState() {
  super.initState();
  AppOpenAdManager.isInProScreen = true; // onAppear
}

@override
void dispose() {
  AppOpenAdManager.isInProScreen = false; // onDisappear
  super.dispose();
}
```

---

### Rewarded Ad

```dart
// Swift: @StateObject var rewardedVM = RewardedViewModel()
final _rewardedVM = RewardedAdManager();

@override
void initState() {
  super.initState();
  _rewardedVM.onAdDismissed = () { };
  _rewardedVM.onCoinsEarned = (coins) => print('Coins: $coins');
  _rewardedVM.loadAd('ca-app-pub-XXXX/XXXX');
}

// Show only when ready
ElevatedButton(
  onPressed: _rewardedVM.isAdReady ? () => _rewardedVM.showAd() : null,
  child: const Text('Watch Ad'),
)

// Listen to coins — Swift: .onChange(of: rewardedVM.coins)
ListenableBuilder(
  listenable: _rewardedVM,
  builder: (_, __) => Text('Coins: ${_rewardedVM.coins}'),
)
```

---

### Rewarded Interstitial Ad

```dart
// Swift: @StateObject var riVM = RewardedInterstitialViewModel()
final _riVM = RewardedInterstitialAdManager();

@override
void initState() {
  super.initState();
  _riVM.onAdDismissed = () { };
  _riVM.onCoinsEarned = (coins) => print('Coins: $coins');
  _riVM.loadAd('ca-app-pub-XXXX/XXXX');
}

_riVM.showAd();
```

---

### Native Ad

```dart
// Swift: @StateObject var nativeVM = NativeAdViewModel(adUnitID: "...")
final _nativeVM = NativeAdManager(adUnitId: 'ca-app-pub-XXXX/XXXX');

@override
void initState() {
  super.initState();
  _nativeVM.refreshAd(); // Swift: nativeVM.refreshAd()
}

// In build — Swift: GoogleNativeAdView(nativeViewModel: nativeVM)
ListenableBuilder(
  listenable: _nativeVM,
  builder: (_, __) => NativeAdWidget(manager: _nativeVM, height: 300),
)

@override
void dispose() {
  _nativeVM.dispose();
  super.dispose();
}
```

## 📄 License

MIT © [Ameerhamza-tech](https://github.com/Ameerhamza-tech)