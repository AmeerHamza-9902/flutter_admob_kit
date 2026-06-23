import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads/ads_config.dart';
import 'ads/app_open_ad_manager.dart';
import 'ads/interstitial_ad_manager.dart';

/// Convenience facade that wires JSON config to the lower-level ad managers.
class FlutterAdmobKit {
  FlutterAdmobKit._();

  static final FlutterAdmobKit instance = FlutterAdmobKit._();

  AdsConfig _config = const AdsConfig();
  final InterstitialAdManager _bottomNavInterstitial = InterstitialAdManager();
  final InterstitialAdManager _generalClickInterstitial =
      InterstitialAdManager();
  final InterstitialAdManager _proCloseInterstitial = InterstitialAdManager();
  final InterstitialAdManager _splashInterstitial = InterstitialAdManager();
  final AppOpenAdManager _splashAppOpen = AppOpenAdManager();
  final AppOpenAdManager _onResumeAppOpen = AppOpenAdManager();

  AdsConfig get config => _config;

  /// Initializes Mobile Ads and loads local JSON config.
  ///
  /// [remoteKey] is kept for API compatibility. Remote config can be layered by
  /// callers before passing JSON into [AdsConfig.fromJson].
  Future<void> init({String? remoteKey, String? localAsset}) async {
    await MobileAds.instance.initialize();
    if (localAsset != null) {
      _config = await AdsConfig.fromAsset(localAsset);
    }
  }

  Future<bool> showSplashAppOpen() async {
    final slot = _config.splashAppOpen;
    if (!_canShow(slot)) return false;
    await _splashAppOpen.loadAd(slot!.adUnitId!);
    return _splashAppOpen.showAdIfAvailable(slot.adUnitId!);
  }

  Future<bool> showSplashInterstitial(BuildContext context) async {
    final slot = _config.splashInterstitial;
    if (!_canShow(slot)) return false;
    await _splashInterstitial.loadAd(slot!.adUnitId!);
    return _splashInterstitial.showAd();
  }

  bool onBottomNavClick(BuildContext context) {
    final slot = _config.interstitialBtmNav;
    if (!_canShow(slot)) return false;
    return _bottomNavInterstitial.onClickEvent(
      slot!.adUnitId!,
      threshold: slot.clickThreshold,
    );
  }

  bool onGeneralClick(BuildContext context) {
    final slot = _config.clickInterstitial;
    if (slot?.adUnitId == null || !(slot!.isEnabled || slot.show)) {
      return false;
    }
    return _generalClickInterstitial.onClickEvent(
      slot.adUnitId!,
      threshold: slot.clickThreshold,
    );
  }

  Future<bool> showProCloseInterstitial(BuildContext context) async {
    final slot = _config.proCloseInterstitial;
    if (!_canShow(slot)) return false;
    await _proCloseInterstitial.loadAd(slot!.adUnitId!);
    return _proCloseInterstitial.showAd();
  }

  Future<bool> showOnResumeAppOpen() async {
    final slot = _config.onResumeAppOpen;
    if (!_canShow(slot)) return false;
    await _onResumeAppOpen.loadAd(slot!.adUnitId!);
    return _onResumeAppOpen.showAdIfAvailable(slot.adUnitId!);
  }

  ScreenAdConfig screenConfig(String screenKey) =>
      _config.screenConfig(screenKey);

  bool _canShow(AdSlotConfig? slot) {
    return slot?.adUnitId != null && (slot!.show || slot.isEnabled);
  }
}
