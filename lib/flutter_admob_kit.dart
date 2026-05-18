/// flutter_admob_kit
///
/// A production-ready, config-driven AdMob library for Flutter.
/// Supports Firebase Remote Config and local JSON fallback.
///
/// Quick start:
/// ```dart
/// await FlutterAdmobKit.instance.init();
/// ```
library flutter_admob_kit;

export 'src/admob_kit.dart';
export 'src/config/ads_config.dart';
export 'src/config/config_loader.dart';
export 'src/ads/interstitial_ad_manager.dart';
export 'src/ads/app_open_ad_manager.dart';
export 'src/widgets/banner_ad_widget.dart';
export 'src/widgets/native_ad_widget.dart';
