import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_state.dart';
import 'app_open/app_open_manager.dart';
import 'consent_manager.dart';
import 'interstitial/interstitial_manager.dart';
import 'lifecycle_manager.dart';
import 'rewarded/rewarded_manager.dart';

/// Central entry point for flutter_admob_kit.
///
/// Designed to behave like a lightweight internal AdMob SDK:
/// - Configure Ad Unit IDs once during initialization.
/// - Control fullscreen ads with simple calls like `AdMobKit.interstitial.show(true)`.
/// - Automatic preloading, exponential retries, expiry validation, and app resume lifecycle.
///
/// ```dart
/// await AdMobKit.initialize(
///   config: AdMobConfig(
///     android: AdPlatformConfig(interstitial: '...'),
///     ios: AdPlatformConfig(interstitial: '...'),
///     testMode: false,
///   ),
/// );
/// ```
class AdMobKit {
  AdMobKit._();

  static final AdMobKit _singleton = AdMobKit._();

  /// Shared singleton instance for convenience and backward compatibility.
  static AdMobKit get instance => _singleton;

  static AdMobConfig _config = const AdMobConfig();
  static bool _isInitialized = false;
  static bool _isEntitled = false;

  static InterstitialManager? _interstitial;
  static RewardedManager? _rewarded;
  static AppOpenManager? _appOpen;
  static LifecycleManager? _lifecycleManager;

  static final List<void Function(AdEvent event)> _eventListeners = [];

  /// Current active [AdMobConfig].
  static AdMobConfig get config => _config;

  /// Whether [AdMobKit.initialize] has completed.
  static bool get isInitialized => _isInitialized;

  /// Whether the user is entitled (ad-free premium).
  static bool get isEntitled => _isEntitled || _config.isEntitled;

  /// The active [InterstitialManager] instance.
  static InterstitialManager get interstitial {
    _ensureInitialized();
    return _interstitial!;
  }

  /// The active [RewardedManager] instance.
  static RewardedManager get rewarded {
    _ensureInitialized();
    return _rewarded!;
  }

  /// The active [AppOpenManager] instance.
  static AppOpenManager get appOpen {
    _ensureInitialized();
    return _appOpen!;
  }

  /// Initializes the AdMob SDK and internal managers.
  ///
  /// This method is strictly idempotent: calling it multiple times will not
  /// duplicate SDK initialization, lifecycle observers, or network requests.
  static Future<void> initialize({
    AdMobConfig? config,
    bool autoPreload = true,
  }) async {
    if (_isInitialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    if (config != null) {
      _config = config;
      _isEntitled = config.isEntitled;
    }

    // 1. Google UMP Consent flow (if enabled)
    if (_config.enableUmpConsent) {
      try {
        await ConsentManager.instance.requestConsent();
      } catch (_) {}
    }

    // 2. Initialize Google Mobile Ads SDK
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}

    // 3. Setup internal managers
    _interstitial = InterstitialManager(
      adUnitIdProvider: () => _config.interstitialId,
      cooldown: _config.interstitialCooldown,
      adExpiry: _config.interstitialExpiry,
      isEntitledProvider: () => isEntitled,
    )..onEvent = _handleEvent;

    _rewarded = RewardedManager(
      adUnitIdProvider: () => _config.rewardedId,
      adExpiry: _config.rewardedExpiry,
      isEntitledProvider: () => isEntitled,
    )..onEvent = _handleEvent;

    _appOpen = AppOpenManager(
      adUnitIdProvider: () => _config.appOpenId,
      cooldown: _config.appOpenCooldown,
      adExpiry: _config.appOpenExpiry,
      isEntitledProvider: () => isEntitled,
    )..onEvent = _handleEvent;

    // 4. Setup automatic App Open lifecycle observer
    _lifecycleManager = LifecycleManager(
      appOpenManager: _appOpen!,
      isEnabled: _config.autoResumeAppOpen,
    )..start();

    _isInitialized = true;

    // 5. Initial eager preloads
    if (autoPreload && !isEntitled) {
      if (_config.interstitialId != null) {
        _interstitial!.preload();
      }
      if (_config.appOpenId != null) {
        _appOpen!.preload();
      }
    }
  }

  /// Sets the user's entitlement status.
  ///
  /// When `true`, all ad requests and presentations are suppressed, and
  /// active banner and native widgets automatically collapse to zero height.
  static void setEntitled(bool entitled) {
    _isEntitled = entitled;
    _config = _config.copyWith(isEntitled: entitled);
  }

  /// Updates runtime configuration dynamically.
  static void updateConfig(AdMobConfig newConfig) {
    _config = newConfig;
    _isEntitled = newConfig.isEntitled;
    if (_lifecycleManager != null) {
      _lifecycleManager!.isEnabled = newConfig.autoResumeAppOpen;
    }
    if (_interstitial != null) {
      _interstitial!.cooldown = newConfig.interstitialCooldown;
      _interstitial!.adExpiry = newConfig.interstitialExpiry;
    }
    if (_rewarded != null) {
      _rewarded!.adExpiry = newConfig.rewardedExpiry;
    }
    if (_appOpen != null) {
      _appOpen!.cooldown = newConfig.appOpenCooldown;
      _appOpen!.adExpiry = newConfig.appOpenExpiry;
    }
  }

  /// Adds a listener for global ad lifecycle events.
  static void addEventListener(void Function(AdEvent event) listener) {
    if (!_eventListeners.contains(listener)) {
      _eventListeners.add(listener);
    }
  }

  /// Removes an ad lifecycle event listener.
  static void removeEventListener(void Function(AdEvent event) listener) {
    _eventListeners.remove(listener);
  }

  static void _handleEvent(AdEvent event) {
    for (final listener in List.of(_eventListeners)) {
      try {
        listener(event);
      } catch (e) {
        debugPrint('flutter_admob_kit: Error in ad event listener: $e');
      }
    }
  }

  static void _ensureInitialized() {
    if (!_isInitialized) {
      // Lazy fallback initialization with default config to prevent crashes
      _interstitial ??= InterstitialManager(
        adUnitIdProvider: () => _config.interstitialId,
        isEntitledProvider: () => isEntitled,
      );
      _rewarded ??= RewardedManager(
        adUnitIdProvider: () => _config.rewardedId,
        isEntitledProvider: () => isEntitled,
      );
      _appOpen ??= AppOpenManager(
        adUnitIdProvider: () => _config.appOpenId,
        isEntitledProvider: () => isEntitled,
      );
    }
  }

  /// Resets internal state (useful for unit tests).
  @visibleForTesting
  static void resetForTesting() {
    _lifecycleManager?.stop();
    _lifecycleManager = null;
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
    _appOpen?.dispose();
    _appOpen = null;
    _eventListeners.clear();
    _isInitialized = false;
    _isEntitled = false;
    _config = const AdMobConfig();
  }

  // ─── Backward Compatibility Helpers ─────────────────────────────────────

  /// Deprecated convenience method for backward compatibility.
  /// Prefer `AdMobKit.initialize(config: ...)`.
  Future<void> init({
    String? localAsset,
    AdMobConfig? config,
    Map<String, dynamic>? rawJson,
    String? remoteKey,
  }) async {
    await AdMobKit.initialize(config: config);
  }

  /// Deprecated: Shows Interstitial ad. Prefer `AdMobKit.interstitial.show(true)`.
  Future<bool> showSplashInterstitial([BuildContext? context]) =>
      AdMobKit.interstitial.show(true);

  /// Deprecated: Shows App Open ad. Prefer `AdMobKit.appOpen.show(true)`.
  Future<bool> showSplashAppOpen() => AdMobKit.appOpen.show(true);

  /// Deprecated: Shows App Open ad on resume.
  Future<bool> showOnResumeAppOpen() => AdMobKit.appOpen.show(true);

  /// Deprecated: Handles click threshold. Prefer `AdMobKit.interstitial.show(true)`.
  bool onBottomNavClick([BuildContext? context]) {
    AdMobKit.interstitial.show(true);
    return true;
  }

  /// Deprecated: Handles click threshold. Prefer `AdMobKit.interstitial.show(true)`.
  bool onGeneralClick([BuildContext? context]) {
    AdMobKit.interstitial.show(true);
    return true;
  }

  /// Deprecated: Shows Pro Close Interstitial. Prefer `AdMobKit.interstitial.show(true)`.
  Future<bool> showProCloseInterstitial([BuildContext? context]) =>
      AdMobKit.interstitial.show(true);
}
