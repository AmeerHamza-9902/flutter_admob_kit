/// A lightweight, production-ready internal AdMob SDK for Flutter.
///
/// ## Quick Start
/// ```dart
/// // 1. Initialize once in main()
/// await AdMobKit.initialize(
///   config: AdMobConfig(
///     android: AdPlatformConfig(
///       interstitial: 'ca-app-pub-XXXX/XXXX',
///       rewarded: 'ca-app-pub-XXXX/XXXX',
///       appOpen: 'ca-app-pub-XXXX/XXXX',
///       banner: 'ca-app-pub-XXXX/XXXX',
///       native: 'ca-app-pub-XXXX/XXXX',
///     ),
///     testMode: false,
///   ),
/// );
///
/// // 2. Show Interstitial
/// AdMobKit.interstitial.show(true);
///
/// // 3. Show Rewarded
/// AdMobKit.rewarded.show(true, onReward: (reward) {
///   // reward user
/// });
///
/// // 4. Display Banner or Native widgets
/// const BannerAdWidget();
/// const NativeAdWidget.medium();
/// ```
library;

export 'src/ad_config.dart';
export 'src/ad_orchestrator.dart';
export 'src/ad_state.dart';
export 'src/admob_kit.dart';
export 'src/app_open/app_open_manager.dart';
export 'src/banner/banner_ad_widget.dart';
export 'src/banner/banner_manager.dart';
export 'src/consent_manager.dart';
export 'src/interstitial/interstitial_manager.dart';
export 'src/lifecycle_manager.dart';
export 'src/native/native_ad_widget.dart';
export 'src/native/native_templates.dart';
export 'src/retry_policy.dart';
export 'src/rewarded/rewarded_manager.dart';
export 'src/widgets/ad_shimmer_placeholder.dart';
export 'src/widgets/paywall_close_guard.dart';
