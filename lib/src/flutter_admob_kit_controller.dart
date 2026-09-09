import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads/ads_config.dart';
import 'ads/app_open_ad_manager.dart';
import 'ads/interstitial_ad_manager.dart';
import 'ads/ad_presentation_coordinator.dart';

/// Convenience facade that wires JSON config to the lower-level ad managers.
///
/// ## Quick Start
/// ```dart
/// // 1. Initialize in main.dart
/// await AdMobKit.instance.init(localAsset: 'assets/ads_config.json');
///
/// // 2. Optional: automatic App Open ad on app resume
/// AdMobKit.instance.enableAutoResumeAppOpen();
///
/// // 3. Premium user? All ads disappear instantly:
/// AdMobKit.instance.setEntitled(true);
///
/// // 4. Firebase Remote Config update:
/// AdMobKit.instance.updateConfigFromJson(remoteJson);
/// ```
class FlutterAdmobKit extends ChangeNotifier {
  FlutterAdmobKit._();

  /// The global shared singleton instance.
  static final FlutterAdmobKit instance = FlutterAdmobKit._();

  AdsConfig _config = const AdsConfig();
  bool _entitled = false;

  final InterstitialAdManager _bottomNavInterstitial = InterstitialAdManager();
  final InterstitialAdManager _generalClickInterstitial =
      InterstitialAdManager();
  final InterstitialAdManager _proCloseInterstitial = InterstitialAdManager();
  final InterstitialAdManager _splashInterstitial = InterstitialAdManager();
  final AppOpenAdManager _splashAppOpen = AppOpenAdManager();
  final AppOpenAdManager _onResumeAppOpen = AppOpenAdManager();

  /// The currently loaded [AdsConfig].
  AdsConfig get config => _config;

  /// Whether the user is entitled / premium (all ads suppressed).
  bool get isEntitled => _entitled || _config.isEntitled;

  /// Underlying ad managers for custom callbacks and listeners.
  InterstitialAdManager get bottomNavInterstitial => _bottomNavInterstitial;
  InterstitialAdManager get generalClickInterstitial =>
      _generalClickInterstitial;
  InterstitialAdManager get proCloseInterstitial => _proCloseInterstitial;
  InterstitialAdManager get splashInterstitial => _splashInterstitial;
  AppOpenAdManager get splashAppOpen => _splashAppOpen;
  AppOpenAdManager get onResumeAppOpen => _onResumeAppOpen;

  // ─── Initialization ────────────────────────────────────────────────────

  /// Initializes Mobile Ads SDK and loads configuration.
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
    } else if (rawJson != null) {
      _config = AdsConfig.fromJson(rawJson);
    } else if (localAsset != null) {
      _config = await AdsConfig.fromAsset(localAsset);
    }
    notifyListeners();
    _eagerPreloadAll();
  }

  // ─── Config Updates ────────────────────────────────────────────────────

  /// Updates runtime configuration dynamically (e.g. from Remote Config).
  void updateConfig(AdsConfig config, {bool preload = true}) {
    _config = config;
    notifyListeners();
    if (preload) _eagerPreloadAll();
  }

  /// Updates runtime configuration from a raw JSON map.
  void updateConfigFromJson(Map<String, dynamic> json, {bool preload = true}) {
    _config = AdsConfig.fromJson(json);
    notifyListeners();
    if (preload) _eagerPreloadAll();
  }

  // ─── Entitlement Gate ──────────────────────────────────────────────────

  /// Sets the user's entitlement status.
  ///
  /// When `true`, **all** ad load requests and presentations are suppressed.
  /// All currently mounted [BannerAdWidget] and [NativeAdWidget] will
  /// automatically collapse to zero height.
  ///
  /// ```dart
  /// // User purchased premium:
  /// AdMobKit.instance.setEntitled(true);
  /// ```
  void setEntitled(bool entitled) {
    if (_entitled == entitled) return;
    _entitled = entitled;
    notifyListeners();
  }

  // ─── Splash Ads ────────────────────────────────────────────────────────

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

  // ─── Click Counter Ads ─────────────────────────────────────────────────

  /// Handles bottom navigation click events against configured click threshold.
  ///
  /// Automatically tracks clicks and shows interstitial when threshold
  /// is reached. If ad is not ready when threshold fires, the counter
  /// is **not** reset to prevent wasted impressions.
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
    if (!_canShow(slot)) return false;
    return _generalClickInterstitial.onClickEvent(
      slot!.adUnitId!,
      threshold: slot.clickThreshold,
    );
  }

  /// Preloads General Click Interstitial ad in memory.
  Future<bool> preloadClickInterstitial() async {
    final slot = _config.clickInterstitial;
    if (!_canShow(slot)) return false;
    return _generalClickInterstitial.loadAd(slot!.adUnitId!);
  }

  // ─── Pro Close Interstitial ────────────────────────────────────────────

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

  // ─── Resume App Open ───────────────────────────────────────────────────

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

  // ─── Auto Resume Observer ──────────────────────────────────────────────

  _AutoResumeObserver? _resumeObserver;

  /// Automatically monitors app foreground/background state and presents
  /// OnResume App Open ads seamlessly with zero boilerplate code.
  ///
  /// Checks the presentation lease and freshness before showing.
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

  // ─── Screen Config ─────────────────────────────────────────────────────

  /// Resolves banner/native configuration for a specific screen key.
  ScreenAdConfig screenConfig(String screenKey) =>
      _config.screenConfig(screenKey);

  // ─── Internals ─────────────────────────────────────────────────────────

  /// Checks whether a slot can show ads.
  ///
  /// Returns `false` if:
  /// - User is entitled (premium)
  /// - Slot is null or has no ad unit ID
  /// - Slot is disabled (`show` and `isEnabled` both false)
  bool _canShow(AdSlotConfig? slot) {
    if (isEntitled) return false;
    return slot != null && slot.isActive;
  }

  /// Eagerly preloads all enabled fullscreen placements after config loads.
  ///
  /// This ensures ads are primed in memory before the user triggers them,
  /// maximizing show rate and minimizing wasted impression requests.
  void _eagerPreloadAll() {
    if (isEntitled) return;
    final cfg = _config;
    try {
      if (cfg.interstitialBtmNav?.isActive == true) {
        _bottomNavInterstitial.loadAd(cfg.interstitialBtmNav!.adUnitId!);
      }
      if (cfg.clickInterstitial?.isActive == true) {
        _generalClickInterstitial.loadAd(cfg.clickInterstitial!.adUnitId!);
      }
      if (cfg.proCloseInterstitial?.isActive == true) {
        _proCloseInterstitial.loadAd(cfg.proCloseInterstitial!.adUnitId!);
      }
      if (cfg.onResumeAppOpen?.isActive == true) {
        _onResumeAppOpen.loadAd(cfg.onResumeAppOpen!.adUnitId!);
      }
    } catch (_) {
      // In test environments or when SDK is not initialized, ignore gracefully.
    }
  }
}

class _AutoResumeObserver extends WidgetsBindingObserver {
  final FlutterAdmobKit _kit;
  _AutoResumeObserver(this._kit);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Skip if another full-screen ad is already presenting.
      if (AdPresentationCoordinator.instance.isPresenting) return;
      // Skip if on paywall / pro screen.
      if (AppOpenAdManager.isInProScreen) return;
      _kit.showOnResumeAppOpen();
    }
  }
}
