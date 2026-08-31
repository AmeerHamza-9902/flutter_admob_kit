import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads/ads_config.dart';
import 'ads/app_open_ad_manager.dart';
import 'ads/interstitial_ad_manager.dart';

/// Convenience facade that wires JSON config to the lower-level ad managers.
class FlutterAdmobKit extends ChangeNotifier {
  FlutterAdmobKit._();

  /// The global shared singleton instance.
  static final FlutterAdmobKit instance = FlutterAdmobKit._();

  AdsConfig _config = const AdsConfig();
  final InterstitialAdManager _bottomNavInterstitial = InterstitialAdManager();
  final InterstitialAdManager _generalClickInterstitial =
      InterstitialAdManager();
  final InterstitialAdManager _proCloseInterstitial = InterstitialAdManager();
  final InterstitialAdManager _splashInterstitial = InterstitialAdManager();
  final AppOpenAdManager _splashAppOpen = AppOpenAdManager();
  final AppOpenAdManager _onResumeAppOpen = AppOpenAdManager();

  /// The currently loaded [AdsConfig].
  AdsConfig get config => _config;

  /// Underlying ad managers for custom callbacks and listeners.
  InterstitialAdManager get bottomNavInterstitial => _bottomNavInterstitial;
  InterstitialAdManager get generalClickInterstitial => _generalClickInterstitial;
  InterstitialAdManager get proCloseInterstitial => _proCloseInterstitial;
  InterstitialAdManager get splashInterstitial => _splashInterstitial;
  AppOpenAdManager get splashAppOpen => _splashAppOpen;
  AppOpenAdManager get onResumeAppOpen => _onResumeAppOpen;

  /// Initializes Mobile Ads SDK and optionally loads configuration.
  ///
  /// You can pass:
  /// - [localAsset]: Path to asset JSON (e.g. `'assets/ads_config.json'`).
  /// - [config]: An already parsed [AdsConfig] instance.
  /// - [rawJson]: A `Map<String, dynamic>` (e.g. from Firebase Remote Config).
  /// - [remoteKey]: Kept for backwards API compatibility.
  Future<void> init({
    String? remoteKey,
    String? localAsset,
    AdsConfig? config,
    Map<String, dynamic>? rawJson,
  }) async {
    await MobileAds.instance.initialize();
    if (config != null) {
      _config = config;
      notifyListeners();
    } else if (rawJson != null) {
      _config = AdsConfig.fromJson(rawJson);
      notifyListeners();
    } else if (localAsset != null) {
      _config = await AdsConfig.fromAsset(localAsset);
      notifyListeners();
    }
  }

  /// Updates runtime configuration dynamically (e.g. from Remote Config).
  void updateConfig(AdsConfig config) {
    _config = config;
    notifyListeners();
  }

  /// Updates runtime configuration from a raw JSON map (e.g. Firebase Remote Config).
  void updateConfigFromJson(Map<String, dynamic> json) {
    _config = AdsConfig.fromJson(json);
    notifyListeners();
  }

  /// Shows Splash App Open ad.
  /// If not preloaded, loads and shows automatically.
  Future<bool> showSplashAppOpen() async {
    final slot = _config.splashAppOpen;
    if (!_canShow(slot)) return false;
    if (!_splashAppOpen.isAdReady) {
      final loaded = await _splashAppOpen.loadAd(slot!.adUnitId!);
      if (!loaded) return false;
    }
    return _splashAppOpen.showAdIfAvailable(slot!.adUnitId!);
  }

  /// Preloads Splash App Open ad in memory.
  Future<bool> preloadSplashAppOpen() async {
    final slot = _config.splashAppOpen;
    if (!_canShow(slot)) return false;
    return _splashAppOpen.loadAd(slot!.adUnitId!);
  }

  /// Shows Splash Interstitial ad.
  /// If not preloaded, loads and shows automatically.
  Future<bool> showSplashInterstitial(BuildContext context) async {
    final slot = _config.splashInterstitial;
    if (!_canShow(slot)) return false;
    if (!_splashInterstitial.isAdReady) {
      final loaded = await _splashInterstitial.loadAd(slot!.adUnitId!);
      if (!loaded) return false;
    }
    return _splashInterstitial.showAd();
  }

  /// Preloads Splash Interstitial ad in memory.
  Future<bool> preloadSplashInterstitial() async {
    final slot = _config.splashInterstitial;
    if (!_canShow(slot)) return false;
    return _splashInterstitial.loadAd(slot!.adUnitId!);
  }

  /// Handles bottom navigation click events against configured click threshold.
  bool onBottomNavClick(BuildContext context) {
    final slot = _config.interstitialBtmNav;
    if (!_canShow(slot)) return false;
    return _bottomNavInterstitial.onClickEvent(
      slot!.adUnitId!,
      threshold: slot.clickThreshold,
    );
  }

  /// Preloads Bottom Nav Interstitial ad in memory.
  Future<bool> preloadBottomNavInterstitial() async {
    final slot = _config.interstitialBtmNav;
    if (!_canShow(slot)) return false;
    return _bottomNavInterstitial.loadAd(slot!.adUnitId!);
  }

  /// Handles general button click events against configured click threshold.
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

  /// Preloads General Click Interstitial ad in memory.
  Future<bool> preloadClickInterstitial() async {
    final slot = _config.clickInterstitial;
    if (!_canShow(slot)) return false;
    return _generalClickInterstitial.loadAd(slot!.adUnitId!);
  }

  /// Shows Pro Close Interstitial ad.
  Future<bool> showProCloseInterstitial(BuildContext context) async {
    final slot = _config.proCloseInterstitial;
    if (!_canShow(slot)) return false;
    if (!_proCloseInterstitial.isAdReady) {
      final loaded = await _proCloseInterstitial.loadAd(slot!.adUnitId!);
      if (!loaded) return false;
    }
    return _proCloseInterstitial.showAd();
  }

  /// Preloads Pro Close Interstitial ad in memory.
  Future<bool> preloadProCloseInterstitial() async {
    final slot = _config.proCloseInterstitial;
    if (!_canShow(slot)) return false;
    return _proCloseInterstitial.loadAd(slot!.adUnitId!);
  }

  /// Shows OnResume App Open ad.
  Future<bool> showOnResumeAppOpen() async {
    final slot = _config.onResumeAppOpen;
    if (!_canShow(slot)) return false;
    if (!_onResumeAppOpen.isAdReady) {
      final loaded = await _onResumeAppOpen.loadAd(slot!.adUnitId!);
      if (!loaded) return false;
    }
    return _onResumeAppOpen.showAdIfAvailable(slot!.adUnitId!);
  }

  /// Preloads OnResume App Open ad in memory.
  Future<bool> preloadOnResumeAppOpen() async {
    final slot = _config.onResumeAppOpen;
    if (!_canShow(slot)) return false;
    return _onResumeAppOpen.loadAd(slot!.adUnitId!);
  }

  _AutoResumeObserver? _resumeObserver;

  /// Automatically monitors app foreground/background state and presents
  /// OnResume App Open ads seamlessly with zero boilerplate code.
  void enableAutoResumeAppOpen() {
    if (_resumeObserver != null) return;
    _resumeObserver = _AutoResumeObserver(this);
    WidgetsBinding.instance.addObserver(_resumeObserver!);
    preloadOnResumeAppOpen();
  }

  /// Disables automatic App Open resume monitoring.
  void disableAutoResumeAppOpen() {
    if (_resumeObserver == null) return;
    WidgetsBinding.instance.removeObserver(_resumeObserver!);
    _resumeObserver = null;
  }

  /// Resolves banner/native configuration for a specific screen key.
  ScreenAdConfig screenConfig(String screenKey) =>
      _config.screenConfig(screenKey);

  bool _canShow(AdSlotConfig? slot) {
    return slot?.adUnitId != null && (slot!.show || slot.isEnabled);
  }
}

class _AutoResumeObserver extends WidgetsBindingObserver {
  final FlutterAdmobKit _kit;
  _AutoResumeObserver(this._kit);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _kit.showOnResumeAppOpen();
    }
  }
}
