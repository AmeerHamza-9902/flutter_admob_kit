/// A production-ready AdMob library for Flutter.
///
/// Flutter port of [AdMobKit](https://github.com/shahid0/AdMobKit)
/// (Swift/SwiftUI) by Shahid Hussain.
///
/// ## Supported ad formats
/// - [BannerAdWidget] — drop-in banner widget
/// - [InterstitialAdManager] — with click threshold support
/// - [AppOpenAdManager] — with paywall guard
/// - [RewardedAdManager] — with coin tracking
/// - [RewardedInterstitialAdManager] — with coin tracking
/// - [NativeAdManager] + [NativeAdWidget] — ViewModel-driven native ads
///
/// ## Quick start
/// ```dart
/// // Initialize once in main()
/// await MobileAds.instance.initialize();
///
/// // Then use any manager:
/// final vm = InterstitialAdManager();
/// vm.onAdDismissed = () => Navigator.pushNamed(context, '/home');
/// await vm.loadAd('ca-app-pub-XXXX/XXXX');
/// vm.showAd();
/// ```
library;

export 'src/ads/interstitial_ad_manager.dart';
export 'src/ads/app_open_ad_manager.dart';
export 'src/ads/rewarded_ad_manager.dart';
export 'src/ads/rewarded_interstitial_ad_manager.dart';
export 'src/ads/native_ad_manager.dart';
export 'src/ads/ads_config.dart';
export 'src/flutter_admob_kit_controller.dart';
export 'src/widgets/banner_ad_widget.dart';
export 'src/widgets/native_ad_widget.dart';
