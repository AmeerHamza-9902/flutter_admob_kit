/// A production-ready AdMob library for Flutter.
///
/// ## Supported ad formats
/// - [BannerAdWidget] — drop-in banner widget with shimmer placeholder
/// - [InterstitialAdManager] — with click threshold support
/// - [AppOpenAdManager] — with paywall guard and resume lifecycle
/// - [RewardedAdManager] — with coin tracking
/// - [RewardedInterstitialAdManager] — with coin tracking
/// - [NativeAdManager] + [NativeAdWidget] — ViewModel-driven native ads
/// - [PaywallCloseGuard] — hardware back + close button ad guard
/// - [AdPresentationCoordinator] — full-screen mutual exclusion
///
/// ## Quick Start
/// ```dart
/// // Initialize once in main()
/// await AdMobKit.instance.init(localAsset: 'assets/ads_config.json');
/// AdMobKit.instance.enableAutoResumeAppOpen();
///
/// // Premium user? All ads disappear:
/// AdMobKit.instance.setEntitled(true);
///
/// // Firebase Remote Config:
/// AdMobKit.instance.updateConfigFromJson(remoteJson);
/// ```
library;

export 'src/core/ad_lifecycle_mixin.dart';
export 'src/ads/interstitial_ad_manager.dart';
export 'src/ads/app_open_ad_manager.dart';
export 'src/ads/rewarded_ad_manager.dart';
export 'src/ads/rewarded_interstitial_ad_manager.dart';
export 'src/ads/native_ad_manager.dart';
export 'src/ads/ad_presentation_coordinator.dart';
export 'src/ads/ads_config.dart';
export 'src/flutter_admob_kit_controller.dart';
export 'src/widgets/banner_ad_widget.dart';
export 'src/widgets/native_ad_widget.dart';
export 'src/widgets/ad_shimmer_placeholder.dart';
export 'src/widgets/paywall_close_guard.dart';

import 'src/flutter_admob_kit_controller.dart';

/// Shorthand alias for [FlutterAdmobKit] for faster and cleaner code.
typedef AdMobKit = FlutterAdmobKit;
