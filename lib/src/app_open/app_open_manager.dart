import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_orchestrator.dart';
import '../ad_state.dart';
import '../retry_policy.dart';

/// Manages App Open ads, preloading, retries, paywall protection, and presentation.
class AppOpenManager extends ChangeNotifier {
  AppOpenManager({
    this.adUnitIdProvider,
    this.adExpiry = const Duration(hours: 4),
    this.cooldown = const Duration(seconds: 10),
    this.retryPolicy = const RetryPolicy(),
    this.isEntitledProvider,
  });

  /// Function that returns the active ad unit ID.
  final ValueGetter<String?>? adUnitIdProvider;

  /// Function that returns whether the user is entitled (ad-free).
  final ValueGetter<bool>? isEntitledProvider;

  /// Maximum freshness lifespan of a loaded App Open ad (Google advises 4 hours).
  Duration adExpiry;

  /// Cooldown between consecutive App Open presentations.
  Duration cooldown;

  /// Backoff retry policy.
  RetryPolicy retryPolicy;

  /// Flag set when the user is on a paywall / pro purchase screen.
  /// Suppresses App Open ads from interrupting the purchase funnel.
  bool isInPaywall = false;

  AppOpenAd? _ad;
  AdState _state = AdState.idle;
  DateTime? _loadedAt;
  DateTime? _lastShownAt;
  int _retryAttempt = 0;
  Timer? _retryTimer;
  Completer<bool>? _loadCompleter;

  /// Current state of the App Open ad.
  AdState get state => _state;

  /// Whether an ad is loaded and ready to be shown.
  bool get isReady => _state == AdState.ready && !isExpired;

  /// Whether an ad is currently loading.
  bool get isLoading => _state == AdState.loading;

  /// Whether an ad is currently showing on screen.
  bool get isShowing => _state == AdState.showing;

  /// Whether the cached ad has expired.
  bool get isExpired {
    if (_loadedAt == null) return true;
    return DateTime.now().difference(_loadedAt!) > adExpiry;
  }

  /// Whether currently inside the cooldown window.
  bool get isInCooldown {
    if (_lastShownAt == null) return false;
    return DateTime.now().difference(_lastShownAt!) < cooldown;
  }

  /// Callback when an ad lifecycle event occurs.
  void Function(AdEvent event)? onEvent;

  /// Preloads an App Open ad into memory.
  Future<bool> preload([String? overrideAdUnitId]) async {
    if (_state == AdState.disposed) return false;
    if (isEntitledProvider?.call() == true) return false;

    // Evict expired ad
    if (_state == AdState.ready && isExpired) {
      _disposeCurrentAd();
      _state = AdState.idle;
    }

    // Already ready and fresh
    if (_state == AdState.ready && _ad != null) return true;

    // Already in flight
    if (_state == AdState.loading) {
      return _loadCompleter?.future ?? Future.value(false);
    }

    final adUnitId = overrideAdUnitId ?? adUnitIdProvider?.call();
    if (adUnitId == null || adUnitId.isEmpty) {
      return false;
    }

    _state = AdState.loading;
    _loadCompleter = Completer<bool>();
    notifyListeners();

    _fetch(adUnitId);
    return _loadCompleter!.future;
  }

  @protected
  void fetchAd(String adUnitId, AppOpenAdLoadCallback callback) {
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: callback,
    );
  }

  void _fetch(String adUnitId) {
    if (_state == AdState.disposed) {
      _completeLoad(false);
      return;
    }

    fetchAd(
      adUnitId,
      AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          if (_state == AdState.disposed) {
            ad.dispose();
            _completeLoad(false);
            return;
          }
          _ad = ad;
          _state = AdState.ready;
          _loadedAt = DateTime.now();
          _retryAttempt = 0;
          _emitEvent(AdEventType.loaded, adUnitId: adUnitId);
          notifyListeners();
          _completeLoad(true);
        },
        onAdFailedToLoad: (error) {
          if (_state == AdState.disposed) {
            _completeLoad(false);
            return;
          }
          _emitEvent(
            AdEventType.loadFailed,
            adUnitId: adUnitId,
            errorMessage: error.message,
          );
          _handleLoadFailure(adUnitId);
        },
      ),
    );
  }

  void _handleLoadFailure(String adUnitId) {
    _retryAttempt++;
    if (retryPolicy.shouldRetry(_retryAttempt)) {
      final delay = retryPolicy.delayFor(_retryAttempt);
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        if (_state != AdState.disposed && _state != AdState.ready) {
          _fetch(adUnitId);
        }
      });
    } else {
      _state = AdState.idle;
      _retryAttempt = 0;
      notifyListeners();
      _completeLoad(false);
    }
  }

  /// Displays the App Open ad.
  ///
  /// - When [shouldShow] is `false`: Does not show and does not trigger any ad requests.
  /// - When [shouldShow] is `true`: Shows if ready and presentation conditions are met.
  ///
  /// Returns `true` if presented, `false` otherwise.
  Future<bool> show([bool shouldShow = true]) async {
    if (!shouldShow) return false;
    if (_state == AdState.disposed) return false;
    if (isInPaywall) return false;
    if (isEntitledProvider?.call() == true) return false;

    // Check cooldown
    if (isInCooldown) return false;

    // Check expiration
    if (isExpired) {
      _disposeCurrentAd();
      _state = AdState.idle;
      preload();
      return false;
    }

    // Check readiness
    if (_state != AdState.ready || _ad == null) {
      if (_state == AdState.idle) preload();
      return false;
    }

    // Mutual exclusion: acquire fullscreen presentation lock
    if (!AdOrchestrator.instance.tryAcquire('app_open')) {
      return false;
    }

    _state = AdState.showing;
    notifyListeners();

    final activeAd = _ad!;
    activeAd.fullScreenContentCallback =
        FullScreenContentCallback<AppOpenAd>(
      onAdShowedFullScreenContent: (_) {
        _lastShownAt = DateTime.now();
        _emitEvent(AdEventType.shown);
      },
      onAdDismissedFullScreenContent: (ad) {
        _onAdClosed(ad);
        _emitEvent(AdEventType.dismissed);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _onAdClosed(ad);
        _emitEvent(AdEventType.dismissed, errorMessage: error.message);
      },
      onAdClicked: (_) => _emitEvent(AdEventType.clicked),
      onAdImpression: (_) => _emitEvent(AdEventType.impression),
    );

    activeAd.show();
    return true;
  }

  void _onAdClosed(AppOpenAd ad) {
    AdOrchestrator.instance.release('app_open');
    ad.dispose();
    _ad = null;
    _state = AdState.idle;
    _loadedAt = null;
    notifyListeners();

    // Auto-preload the next App Open ad
    if (_state != AdState.disposed && isEntitledProvider?.call() != true) {
      preload();
    }
  }

  void _completeLoad(bool result) {
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      _loadCompleter!.complete(result);
    }
  }

  void _disposeCurrentAd() {
    _ad?.dispose();
    _ad = null;
    _loadedAt = null;
  }

  void _emitEvent(
    AdEventType type, {
    String? adUnitId,
    String? errorMessage,
  }) {
    onEvent?.call(
      AdEvent(
        format: AdFormat.appOpen,
        type: type,
        timestamp: DateTime.now(),
        adUnitId: adUnitId,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  void dispose() {
    if (_state == AdState.showing) {
      AdOrchestrator.instance.release('app_open');
    }
    _state = AdState.disposed;
    _retryTimer?.cancel();
    _completeLoad(false);
    _disposeCurrentAd();
    super.dispose();
  }
}
