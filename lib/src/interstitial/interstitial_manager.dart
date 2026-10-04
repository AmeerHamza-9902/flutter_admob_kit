import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_orchestrator.dart';
import '../ad_state.dart';
import '../retry_policy.dart';

/// Manages the complete lifecycle, preloading, retries, and presentation of
/// Interstitial ads.
class InterstitialManager extends ChangeNotifier {
  InterstitialManager({
    this.adUnitIdProvider,
    this.cooldown = const Duration(seconds: 30),
    this.adExpiry = const Duration(hours: 1),
    this.retryPolicy = const RetryPolicy(),
    this.isEntitledProvider,
    this.canRequestAdsProvider,
  });

  /// Function that returns the active ad unit ID.
  final ValueGetter<String?>? adUnitIdProvider;

  /// Function that returns whether the user is entitled (ad-free).
  final ValueGetter<bool>? isEntitledProvider;

  /// Function that returns whether consent allows ad requests.
  final ValueGetter<bool>? canRequestAdsProvider;

  /// Cooldown between consecutive interstitial presentations.
  Duration cooldown;

  /// Maximum freshness lifespan of a loaded ad.
  Duration adExpiry;

  /// Backoff retry policy.
  RetryPolicy retryPolicy;

  InterstitialAd? _ad;
  AdState _state = AdState.idle;
  DateTime? _loadedAt;
  DateTime? _lastShownAt;
  String? _loadedAdUnitId;
  int _retryAttempt = 0;
  int _generation = 0;
  int? _leaseToken;
  Timer? _retryTimer;
  Completer<bool>? _loadCompleter;

  /// Current state of the interstitial ad.
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

  /// Whether the manager is currently in the presentation cooldown window.
  bool get isInCooldown {
    if (_lastShownAt == null) return false;
    return DateTime.now().difference(_lastShownAt!) < cooldown;
  }

  /// Callback when an ad lifecycle event occurs.
  void Function(AdEvent event)? onEvent;

  /// Preloads an interstitial ad into memory.
  ///
  /// Safe to call multiple times: duplicate calls while loading or ready are
  /// ignored.
  Future<bool> preload([String? overrideAdUnitId]) async {
    if (_state == AdState.disposed) return false;
    if (isEntitledProvider?.call() == true) return false;
    if (canRequestAdsProvider?.call() == false) return false;

    // Evict expired ad
    if (_state == AdState.ready && isExpired) {
      _disposeCurrentAd();
      _state = AdState.idle;
    }

    // Already ready and fresh
    if (_state == AdState.ready && _ad != null) return true;

    // Already in flight — return pending future
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

    _fetch(adUnitId, _generation);
    return _loadCompleter!.future;
  }

  @protected
  void fetchAd(String adUnitId, InterstitialAdLoadCallback callback) {
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: callback,
    );
  }

  void _fetch(String adUnitId, int gen) {
    if (_state == AdState.disposed || gen != _generation) {
      _completeLoad(false);
      return;
    }

    fetchAd(
      adUnitId,
      InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_state == AdState.disposed || gen != _generation) {
            ad.dispose();
            _completeLoad(false);
            return;
          }
          _ad = ad;
          _loadedAdUnitId = adUnitId;
          _state = AdState.ready;
          _loadedAt = DateTime.now();
          _retryAttempt = 0;
          _emitEvent(AdEventType.loaded, adUnitId: adUnitId);
          notifyListeners();
          _completeLoad(true);
        },
        onAdFailedToLoad: (error) {
          if (_state == AdState.disposed || gen != _generation) {
            _completeLoad(false);
            return;
          }
          _emitEvent(
            AdEventType.loadFailed,
            adUnitId: adUnitId,
            errorMessage: error.message,
          );
          _handleLoadFailure(adUnitId, gen);
        },
      ),
    );
  }

  void _handleLoadFailure(String adUnitId, int gen) {
    if (_state == AdState.disposed || gen != _generation) {
      _completeLoad(false);
      return;
    }

    _retryAttempt++;
    if (retryPolicy.shouldRetry(_retryAttempt)) {
      final delay = retryPolicy.delayFor(_retryAttempt);
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        if (_state != AdState.disposed &&
            _state != AdState.ready &&
            gen == _generation) {
          _fetch(adUnitId, gen);
        }
      });
    } else {
      // Stopped retrying until next explicit preload trigger
      _state = AdState.idle;
      _retryAttempt = 0;
      notifyListeners();
      _completeLoad(false);
    }
  }

  /// Displays the interstitial ad.
  ///
  /// - When [shouldShow] is `false`: Does not show and does not trigger any ad requests.
  /// - When [shouldShow] is `true`: Shows if loaded and presentation conditions are met.
  ///
  /// Returns `true` if the ad was presented, `false` otherwise.
  Future<bool> show([bool shouldShow = true]) async {
    if (!shouldShow) return false;
    if (_state == AdState.disposed) return false;
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
      // Not ready: ensure an ad is loading without spamming
      if (_state == AdState.idle) preload();
      return false;
    }

    // Mutual exclusion: acquire fullscreen presentation lock with token
    final token = AdOrchestrator.instance.acquireToken('interstitial');
    if (token == null) {
      return false;
    }
    _leaseToken = token;

    _state = AdState.showing;
    notifyListeners();

    final activeAd = _ad!;
    final currentGen = _generation;
    activeAd.fullScreenContentCallback =
        FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        _lastShownAt = DateTime.now();
        _emitEvent(AdEventType.shown);
      },
      onAdDismissedFullScreenContent: (ad) {
        _onAdClosed(ad, currentGen, token);
        _emitEvent(AdEventType.dismissed);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _onAdClosed(ad, currentGen, token);
        _emitEvent(AdEventType.dismissed, errorMessage: error.message);
      },
      onAdClicked: (_) => _emitEvent(AdEventType.clicked),
      onAdImpression: (_) => _emitEvent(AdEventType.impression),
    );

    activeAd.show();
    return true;
  }

  void _onAdClosed(InterstitialAd ad, int gen, [int? token]) {
    final tokenToRelease = token ?? _leaseToken;
    if (tokenToRelease != null) {
      AdOrchestrator.instance.releaseWithToken(tokenToRelease);
      if (_leaseToken == tokenToRelease) {
        _leaseToken = null;
      }
    }

    ad.dispose();
    _ad = null;
    _loadedAdUnitId = null;
    _loadedAt = null;

    if (_state != AdState.disposed && gen == _generation) {
      _state = AdState.idle;
      notifyListeners();

      // Auto-preload the next interstitial
      if (isEntitledProvider?.call() != true) {
        preload();
      }
    }
  }

  void _completeLoad(bool result) {
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      _loadCompleter!.complete(result);
    }
  }

  /// Disposes currently cached ad and resets state to idle.
  /// If [newAdUnitId] is provided, verifies if the cached ad matches it unless [force] is true.
  void invalidate({String? newAdUnitId, bool force = false}) {
    if (_state == AdState.disposed) return;
    if (!force &&
        newAdUnitId != null &&
        _loadedAdUnitId == newAdUnitId &&
        _ad != null) {
      return; // Still matching
    }
    _generation++;
    _retryTimer?.cancel();
    _completeLoad(false);
    _disposeCurrentAd();
    if (_state != AdState.showing) {
      _state = AdState.idle;
      notifyListeners();
    }
  }

  void _disposeCurrentAd() {
    _ad?.dispose();
    _ad = null;
    _loadedAdUnitId = null;
    _loadedAt = null;
  }

  void _emitEvent(
    AdEventType type, {
    String? adUnitId,
    String? errorMessage,
  }) {
    onEvent?.call(
      AdEvent(
        format: AdFormat.interstitial,
        type: type,
        timestamp: DateTime.now(),
        adUnitId: adUnitId,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _state = AdState.disposed;
    _retryTimer?.cancel();
    _completeLoad(false);
    if (_leaseToken != null) {
      AdOrchestrator.instance.releaseWithToken(_leaseToken!);
      _leaseToken = null;
    }
    _disposeCurrentAd();
    super.dispose();
  }

  @visibleForTesting
  int? get leaseToken => _leaseToken;

  @visibleForTesting
  void setAdForTesting(InterstitialAd ad) {
    _ad = ad;
    _state = AdState.ready;
    _loadedAt = DateTime.now();
  }
}
