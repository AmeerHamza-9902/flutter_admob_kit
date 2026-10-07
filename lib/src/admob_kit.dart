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

class _ConfigChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Central entry point for initialization, ads, entitlement and consent.
class AdMobKit {
  AdMobKit._();

  static AdMobConfig _config = const AdMobConfig();
  static bool _isInitialized = false;

  static InterstitialManager? _interstitial;
  static RewardedManager? _rewarded;
  static AppOpenManager? _appOpen;
  static LifecycleManager? _lifecycleManager;

  static final _ConfigChangeNotifier _configNotifier = _ConfigChangeNotifier();

  /// Listenable that notifies when configuration or entitlement changes at runtime.
  static Listenable get configNotifier => _configNotifier;

  static final List<void Function(AdEvent event)> _eventListeners = [];

  /// Current active [AdMobConfig].
  static AdMobConfig get config => _config;

  /// Whether [AdMobKit.initialize] has completed.
  static bool get isInitialized => _isInitialized;

  /// Whether the user is entitled (ad-free premium).
  static bool get isEntitled => _config.isEntitled;

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
  static ConsentRequestParameters? _consentParameters;

  /// Initializes the AdMob SDK and internal managers.
  ///
  /// This method is strictly idempotent: concurrent or repeated calls will share
  /// the same initialization future and will not duplicate SDK initialization,
  /// lifecycle observers, or network requests.
  static Future<void> initialize({
    AdMobConfig? config,
    bool autoPreload = true,
    ConsentRequestParameters? consentParameters,
  }) {
    if (_isInitialized) return Future.value();
    if (_initFuture != null) return _initFuture!;

    final future = _doInitialize(
      config: config,
      autoPreload: autoPreload,
      consentParameters: consentParameters,
    );

    _initFuture = future.then(
      (value) => value,
      onError: (error, stackTrace) {
        _initFuture = null;
        _isInitialized = false;
        return Future<void>.error(error, stackTrace);
      },
    );

    return _initFuture!;
  }

  @visibleForTesting
  static void Function()? testHookBeforeInit;

  static Future<void> _doInitialize({
    AdMobConfig? config,
    bool autoPreload = true,
    ConsentRequestParameters? consentParameters,
  }) async {
    try {
      testHookBeforeInit?.call();
      WidgetsFlutterBinding.ensureInitialized();
      _consentParameters = consentParameters;

      if (config != null) {
        final entitled = isEntitled || config.isEntitled;
        _config = config.copyWith(isEntitled: entitled);
      }

      if (_config.enableUmpConsent) {
        await consent.requestConsent(parameters: consentParameters);
      }

      // Initialization errors must not expose request-capable managers.
      await MobileAds.instance.initialize();
      if (!_config.enableUmpConsent) await consent.canRequestAds();

      bool canRequest() => canRequestAds;
      bool canShow() {
        final state = WidgetsBinding.instance.lifecycleState;
        return state == null ||
            state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive;
      }

      bool canShowAppOpen() {
        final state = WidgetsBinding.instance.lifecycleState;
        return state == null ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.resumed;
      }

      _interstitial = InterstitialManager(
        adUnitIdProvider: () => _config.interstitialId,
        cooldown: _config.interstitialCooldown,
        adExpiry: _config.interstitialExpiry,
        readinessTimeout: _config.adReadinessTimeout,
        isEntitledProvider: () => isEntitled,
        canRequestAdsProvider: canRequest,
        canShowAdsProvider: canShow,
      )..onEvent = _handleEvent;

      _rewarded = RewardedManager(
        adUnitIdProvider: () => _config.rewardedId,
        adExpiry: _config.rewardedExpiry,
        readinessTimeout: _config.adReadinessTimeout,
        isEntitledProvider: () => isEntitled,
        canRequestAdsProvider: canRequest,
        canShowAdsProvider: canShow,
      )..onEvent = _handleEvent;

      _appOpen = AppOpenManager(
        adUnitIdProvider: () => _config.appOpenId,
        cooldown: _config.appOpenCooldown,
        adExpiry: _config.appOpenExpiry,
        readinessTimeout: _config.adReadinessTimeout,
        isEntitledProvider: () => isEntitled,
        canRequestAdsProvider: canRequest,
        canShowAdsProvider: canShowAppOpen,
      )..onEvent = _handleEvent;

      _lifecycleManager = LifecycleManager(
        appOpenManager: _appOpen!,
        isEnabled: _config.autoResumeAppOpen,
      )..start();

      _isInitialized = true;

      ConsentManager.instance.addListener(_onConsentChanged);
      _autoPreload = autoPreload;
      _configNotifier.notify();
      if (autoPreload) _preload();
    } catch (e) {
      _initFuture = null;
      _isInitialized = false;
      rethrow;
    }
  }

  static bool _autoPreload = true;

  /// All formats share this gate, including when UMP is managed by the host.
  static bool get canRequestAds =>
      _isInitialized && !isEntitled && ConsentManager.instance.isConsentSafe;

  static void _preload() {
    if (!canRequestAds) return;
    unawaited(_interstitial!.preload());
    unawaited(_rewarded!.preload());
    unawaited(_appOpen!.preload());
  }

  static void _invalidateAll() {
    _interstitial?.invalidate(force: true);
    _rewarded?.invalidate(force: true);
    _appOpen?.invalidate(force: true);
  }

  static void _onConsentChanged() {
    if (!canRequestAds) _invalidateAll();
    _configNotifier.notify();
    if (_autoPreload) _preload();
  }

  /// Sets the user's entitlement status.
  ///
  /// When `true`, all ad requests and presentations are suppressed, cached ads
  /// are immediately invalidated, and active banner/native widgets collapse.
  /// When `false`, preloading resumes if consent permits.
  static void setEntitled(bool entitled) {
    if (isEntitled == entitled) return;
    _config = _config.copyWith(isEntitled: entitled);
    if (entitled) _invalidateAll();
    _configNotifier.notify();
    if (!entitled && _autoPreload) _preload();
  }

  /// Updates code-owned configuration, preserving active presentations.
  static void updateConfig(AdMobConfig newConfig) {
    final old = _config;
    // Entitlement changes must be explicit through setEntitled(false). A
    // routine ad-unit/config refresh must never re-enable ads for premium users.
    newConfig = newConfig.copyWith(
      isEntitled: old.isEntitled || newConfig.isEntitled,
    );
    _config = newConfig;
    _lifecycleManager?.isEnabled = newConfig.autoResumeAppOpen;
    _interstitial?.cooldown = newConfig.interstitialCooldown;
    _interstitial?.adExpiry = newConfig.interstitialExpiry;
    _interstitial?.readinessTimeout = newConfig.adReadinessTimeout;
    _rewarded?.adExpiry = newConfig.rewardedExpiry;
    _rewarded?.readinessTimeout = newConfig.adReadinessTimeout;
    _appOpen?.cooldown = newConfig.appOpenCooldown;
    _appOpen?.adExpiry = newConfig.appOpenExpiry;
    _appOpen?.readinessTimeout = newConfig.adReadinessTimeout;
    final modeChanged = old.testMode != newConfig.testMode;
    final interstitialChanged =
        modeChanged ||
        old.interstitialId != newConfig.interstitialId ||
        old.interstitialExpiry != newConfig.interstitialExpiry;
    final rewardedChanged =
        modeChanged ||
        old.rewardedId != newConfig.rewardedId ||
        old.rewardedExpiry != newConfig.rewardedExpiry;
    final appOpenChanged =
        modeChanged ||
        old.appOpenId != newConfig.appOpenId ||
        old.appOpenExpiry != newConfig.appOpenExpiry;
    if (modeChanged || old.interstitialId != newConfig.interstitialId) {
      _interstitial?.invalidate(force: true);
    }
    if (modeChanged || old.rewardedId != newConfig.rewardedId) {
      _rewarded?.invalidate(force: true);
    }
    if (modeChanged || old.appOpenId != newConfig.appOpenId) {
      _appOpen?.invalidate(force: true);
    }
    if (isEntitled) _invalidateAll();
    if (!old.enableUmpConsent && newConfig.enableUmpConsent) {
      unawaited(consent.requestConsent(parameters: _consentParameters));
    }
    _configNotifier.notify();
    if (_autoPreload && canRequestAds) {
      if (old.isEntitled && !newConfig.isEntitled) {
        _preload();
      } else {
        if (interstitialChanged) unawaited(_interstitial!.preload());
        if (rewardedChanged) unawaited(_rewarded!.preload());
        if (appOpenChanged) unawaited(_appOpen!.preload());
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

  /// Routes SDK callbacks from owned placements to optional local listeners.
  static void reportEvent(AdEvent event) => _handleEvent(event);

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
      throw StateError(
        'Await AdMobKit.initialize() before accessing managers.',
      );
    }
  }

  /// Resets internal state (useful for unit tests).
  @visibleForTesting
  static void resetForTesting() {
    ConsentManager.instance.removeListener(_onConsentChanged);
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
    _initFuture = null;
    _autoPreload = true;
    testHookBeforeInit = null;
    _consentParameters = null;
    _config = const AdMobConfig();
    _configNotifier.notify();
  }
}
