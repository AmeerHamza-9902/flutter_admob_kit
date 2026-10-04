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

  /// The active [ConsentManager] instance for GDPR and privacy consent.
  static ConsentManager get consent => ConsentManager.instance;

  /// Shows the Google Privacy Options consent form (e.g. from app settings or privacy policy screen).
  ///
  /// Returns `true` if the form was successfully shown, `false` otherwise.
  static Future<bool> showPrivacyConsentForm() =>
      ConsentManager.instance.showPrivacyOptionsForm();

  static Future<void>? _initFuture;

  /// Initializes the AdMob SDK and internal managers.
  ///
  /// This method is strictly idempotent: concurrent or repeated calls will share
  /// the same initialization future and will not duplicate SDK initialization,
  /// lifecycle observers, or network requests.
  static Future<void> initialize({
    AdMobConfig? config,
    bool autoPreload = true,
  }) {
    if (_isInitialized) return Future.value();
    if (_initFuture != null) return _initFuture!;

    _initFuture = _doInitialize(
      config: config,
      autoPreload: autoPreload,
    );

    return _initFuture!;
  }

  static Future<void> _doInitialize({
    AdMobConfig? config,
    bool autoPreload = true,
  }) async {
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
    bool canRequest() =>
        !_config.enableUmpConsent || ConsentManager.instance.isConsentSafe;

    _interstitial = InterstitialManager(
      adUnitIdProvider: () => _config.interstitialId,
      cooldown: _config.interstitialCooldown,
      adExpiry: _config.interstitialExpiry,
      isEntitledProvider: () => isEntitled,
      canRequestAdsProvider: canRequest,
    )..onEvent = _handleEvent;

    _rewarded = RewardedManager(
      adUnitIdProvider: () => _config.rewardedId,
      adExpiry: _config.rewardedExpiry,
      isEntitledProvider: () => isEntitled,
      canRequestAdsProvider: canRequest,
    )..onEvent = _handleEvent;

    _appOpen = AppOpenManager(
      adUnitIdProvider: () => _config.appOpenId,
      cooldown: _config.appOpenCooldown,
      adExpiry: _config.appOpenExpiry,
      isEntitledProvider: () => isEntitled,
      canRequestAdsProvider: canRequest,
    )..onEvent = _handleEvent;

    // 4. Setup automatic App Open lifecycle observer
    _lifecycleManager = LifecycleManager(
      appOpenManager: _appOpen!,
      isEnabled: _config.autoResumeAppOpen,
    )..start();

    _isInitialized = true;

    // 5. Initial eager preloads (only if permitted by consent and entitlement)
    if (autoPreload && !isEntitled) {
      final canRequest = await ConsentManager.instance.canRequestAds();
      if (canRequest && !isEntitled) {
        if (_config.interstitialId != null) {
          _interstitial!.preload();
        }
        if (_config.appOpenId != null) {
          _appOpen!.preload();
        }
      }
    }
  }

  /// Sets the user's entitlement status.
  ///
  /// When `true`, all ad requests and presentations are suppressed, cached ads
  /// are immediately invalidated, and active banner/native widgets collapse.
  /// When `false`, preloading resumes if consent permits.
  static void setEntitled(bool entitled) {
    final wasEntitled = _isEntitled;
    _isEntitled = entitled;
    _config = _config.copyWith(isEntitled: entitled);

    if (entitled) {
      // Evict all preloaded cached ads and cancel timers
      _interstitial?.invalidate();
      _rewarded?.invalidate();
      _appOpen?.invalidate();
    } else if (wasEntitled && _isInitialized) {
      // Re-prime preloaded ads if allowed
      ConsentManager.instance.canRequestAds().then((canRequest) {
        if (canRequest && !isEntitled) {
          if (_config.interstitialId != null) _interstitial?.preload();
          if (_config.appOpenId != null) _appOpen?.preload();
        }
      });
    }
  }

  /// Updates runtime configuration dynamically.
  static void updateConfig(AdMobConfig newConfig) {
    final oldConfig = _config;
    _config = newConfig;
    _isEntitled = newConfig.isEntitled;

    if (newConfig.isEntitled) {
      setEntitled(true);
      return;
    }

    if (_lifecycleManager != null) {
      _lifecycleManager!.isEnabled = newConfig.autoResumeAppOpen;
    }

    if (_interstitial != null) {
      _interstitial!.cooldown = newConfig.interstitialCooldown;
      _interstitial!.adExpiry = newConfig.interstitialExpiry;
      if (oldConfig.interstitialId != newConfig.interstitialId) {
        _interstitial!.invalidate(newAdUnitId: newConfig.interstitialId);
      }
    }
    if (_rewarded != null) {
      _rewarded!.adExpiry = newConfig.rewardedExpiry;
      if (oldConfig.rewardedId != newConfig.rewardedId) {
        _rewarded!.invalidate(newAdUnitId: newConfig.rewardedId);
      }
    }
    if (_appOpen != null) {
      _appOpen!.cooldown = newConfig.appOpenCooldown;
      _appOpen!.adExpiry = newConfig.appOpenExpiry;
      if (oldConfig.appOpenId != newConfig.appOpenId) {
        _appOpen!.invalidate(newAdUnitId: newConfig.appOpenId);
      }
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
    _initFuture = null;
    _config = const AdMobConfig();
  }
}
