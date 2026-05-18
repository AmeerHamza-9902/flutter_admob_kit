// lib/src/admob_kit.dart

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'config/ads_config.dart';
import 'config/config_loader.dart';
import 'ads/interstitial_ad_manager.dart';
import 'ads/app_open_ad_manager.dart';

/// Main entry point for flutter_admob_kit.
///
/// Initialize once in main():
/// ```dart
/// await FlutterAdmobKit.instance.init();
/// ```
class FlutterAdmobKit {
  FlutterAdmobKit._();
  static final FlutterAdmobKit instance = FlutterAdmobKit._();

  late AdsConfig _config;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  // ─── Init ──────────────────────────────────────────────────────────────────

  /// Initialize the kit.
  /// Loads config from Firebase Remote Config, falls back to local asset.
  ///
  /// [remoteKey]  — Firebase Remote Config key (default: 'ads_config')
  /// [localAsset] — Fallback asset path (default: 'assets/ads_config.json')
  Future<void> init({
    String remoteKey = 'ads_config',
    String localAsset = 'assets/ads_config.json',
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    await MobileAds.instance.initialize();
    _config = await ConfigLoader.load(
      remoteKey: remoteKey,
      localAsset: localAsset,
    );
    _initialized = true;
    _preloadOnResumeAd();
  }

  /// Initialize with a manually provided [AdsConfig] (useful for testing).
  Future<void> initWithConfig(AdsConfig config) async {
    WidgetsFlutterBinding.ensureInitialized();
    await MobileAds.instance.initialize();
    _config = config;
    _initialized = true;
    _preloadOnResumeAd();
  }

  void _preloadOnResumeAd() {
    final slot = _config.onResumeAppOpen;
    if (slot != null && slot.show && slot.adUnit.isNotEmpty) {
      AppOpenAdManager.instance.preload(slot.adUnit);
    }
  }

  AdsConfig get config {
    assert(_initialized, 'FlutterAdmobKit is not initialized. Call init() first.');
    return _config;
  }

  // ─── Interstitials ─────────────────────────────────────────────────────────

  /// Call on bottom navigation tap.
  /// Shows interstitial after [click_threshold] taps.
  void onBottomNavClick(BuildContext context) {
    final slot = _config.interstitialBtmNav;
    if (slot == null || !slot.show) return;
    InterstitialAdManager.instance
        .onClickEvent(context, slot.adUnit, slot.clickThreshold, 'btm_nav');
  }

  /// Call on any general button/item click.
  /// Shows interstitial after [click_threshold] taps.
  void onGeneralClick(BuildContext context) {
    final slot = _config.clickInterstitial;
    if (slot == null || !slot.isEnabled) return;
    InterstitialAdManager.instance
        .onClickEvent(context, slot.adUnitId, slot.clickThreshold, 'general');
  }

  /// Show interstitial immediately when user taps close on pro/premium screen.
  Future<void> showProCloseInterstitial(BuildContext context) async {
    final slot = _config.proCloseInterstitial;
    if (slot == null || !slot.show) return;
    await InterstitialAdManager.instance.showNow(context, slot.adUnit);
  }

  /// Show interstitial during splash screen.
  Future<void> showSplashInterstitial(BuildContext context) async {
    final slot = _config.splashInterstitial;
    if (slot == null || !slot.show) return;
    await InterstitialAdManager.instance.showNow(context, slot.adUnit);
  }

  // ─── App Open Ads ──────────────────────────────────────────────────────────

  /// Show App Open ad on splash screen.
  Future<void> showSplashAppOpen() async {
    final slot = _config.splashAppOpen;
    if (slot == null || !slot.show) return;
    await AppOpenAdManager.instance.show(slot.adUnit);
  }

  /// Show App Open ad when app comes to foreground.
  Future<void> showOnResumeAppOpen() async {
    final slot = _config.onResumeAppOpen;
    if (slot == null || !slot.show) return;
    await AppOpenAdManager.instance.show(slot.adUnit);
  }

  // ─── Screen helpers ────────────────────────────────────────────────────────

  /// Get the full [ScreenAdConfig] for a screen key.
  ScreenAdConfig screenConfig(String screenKey) =>
      _config.screenConfig(screenKey);

  /// Returns true if banner ads are enabled for [screenKey].
  bool isBannerEnabled(String screenKey) {
    final s = _config.screenConfig(screenKey);
    return s.bannerAds && (s.bannerId?.isNotEmpty ?? false);
  }

  /// Returns true if native ads are enabled for [screenKey].
  bool isNativeEnabled(String screenKey) {
    final s = _config.screenConfig(screenKey);
    return s.nativeAds && (s.nativeId?.isNotEmpty ?? false);
  }

  /// Get banner ad unit ID for [screenKey], or null.
  String? getBannerId(String screenKey) =>
      _config.screenConfig(screenKey).bannerId;

  /// Get native ad unit ID for [screenKey], or null.
  String? getNativeId(String screenKey) =>
      _config.screenConfig(screenKey).nativeId;
}
