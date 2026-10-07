import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_orchestrator.dart';
import 'ad_state.dart';
import 'retry_policy.dart';

/// Shared single-slot lifecycle for the three fullscreen formats.
abstract class FullscreenManager<T extends AdWithoutView>
    extends ChangeNotifier {
  FullscreenManager({
    required this.format,
    this.adUnitIdProvider,
    this.isEntitledProvider,
    this.canRequestAdsProvider,
    this.canShowAdsProvider,
    required this.adExpiry,
    this.cooldown = Duration.zero,
    this.retryPolicy = const RetryPolicy(),
    this.readinessTimeout = const Duration(seconds: 12),
  });

  final AdFormat format;
  final ValueGetter<String?>? adUnitIdProvider;
  final ValueGetter<bool>? isEntitledProvider;
  final ValueGetter<bool>? canRequestAdsProvider;
  final ValueGetter<bool>? canShowAdsProvider;
  Duration adExpiry;
  Duration cooldown;
  RetryPolicy retryPolicy;
  Duration readinessTimeout;
  void Function(AdEvent event)? onEvent;

  T? _ad;
  AdState _state = AdState.idle;
  DateTime? _loadedAt;
  DateTime? _lastShownAt;
  DateTime? _retryAfter;
  String? _loadedId;
  int _generation = 0;
  int _retryAttempt = 0;
  int? _leaseToken;
  Timer? _retryTimer;
  Completer<bool>? _loadCompleter;
  bool _requestActive = false;
  String? _requestId;
  bool _reloadPending = false;
  String? _pendingId;
  Completer<bool>? _pendingLoadCompleter;

  AdState get state => _state;
  bool get isLoading => _state == AdState.loading;
  bool get isShowing => _state == AdState.showing;
  bool get isReady => _state == AdState.ready && !isExpired && _allowed;
  bool get isExpired =>
      _loadedAt == null ||
      DateTime.now().difference(_loadedAt!) >=
          (adExpiry >
                  (format == AdFormat.appOpen
                      ? const Duration(hours: 4)
                      : const Duration(hours: 1))
              ? (format == AdFormat.appOpen
                    ? const Duration(hours: 4)
                    : const Duration(hours: 1))
              : adExpiry);
  bool get isInCooldown =>
      _lastShownAt != null &&
      cooldown > Duration.zero &&
      DateTime.now().difference(_lastShownAt!) < cooldown;

  /// Clears the last shown timestamp, effectively resetting any active cooldown.
  void resetCooldown() {
    _lastShownAt = null;
    notifyListeners();
  }

  bool get _allowed =>
      _state != AdState.disposed &&
      isEntitledProvider?.call() != true &&
      canRequestAdsProvider?.call() != false;

  /// Placement-specific gate checked again after synchronous event listeners.
  @protected
  bool get canPresentNow => true;

  String get _ineligibilityReason {
    if (_state == AdState.disposed) return 'disposed';
    if (isEntitledProvider?.call() == true) return 'premium';
    if (canRequestAdsProvider?.call() == false) {
      return 'consent_or_initialization';
    }
    return 'ineligible';
  }

  /// Reuses the cache or current request. Never replaces a slow active request.
  Future<bool> preload([String? overrideAdUnitId]) {
    if (!_allowed || isShowing) return Future.value(false);
    final id = overrideAdUnitId ?? adUnitIdProvider?.call();
    if (id == null || id.trim().isEmpty) return Future.value(false);
    if (isReady && _loadedId == id) {
      emit(AdEventType.cacheHit, reason: 'preload');
      return Future.value(true);
    }
    if ((isReady && _loadedId != id) || (isLoading && _requestId != id)) {
      invalidate(force: true);
    }
    if (isLoading) return _loadCompleter!.future;
    if (_requestActive) {
      // Native loads cannot be cancelled. Coalesce changes until it settles.
      if (_reloadPending && _pendingId != id) _completePendingLoad(false);
      _reloadPending = true;
      _pendingId = id;
      return (_pendingLoadCompleter ??= Completer<bool>()).future;
    }
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) {
      return Future.value(false);
    }
    if (_ad != null && isExpired) emit(AdEventType.expired);
    _disposeCached();
    _state = AdState.loading;
    final completion = _loadCompleter = Completer<bool>();
    final gen = ++_generation;
    notifyListeners();
    _fetch(id, gen);
    return completion.future;
  }

  /// Explicitly waits for a ready ad. Ordinary [show] calls remain immediate.
  /// Timeout only ends this caller's wait; a late SDK load remains in the cache.
  Future<bool> waitUntilReady({Duration? timeout}) async {
    if (isReady) return true;
    final limit = timeout ?? readinessTimeout;
    if (limit <= Duration.zero) return false;
    return preload().timeout(
      limit,
      onTimeout: () {
        emit(AdEventType.waitTimedOut, reason: 'readiness_timeout');
        return false;
      },
    );
  }

  @protected
  void requestAd(
    String id,
    void Function(T) loaded,
    void Function(LoadAdError) failed,
  );

  void _fetch(String id, int gen) {
    if (gen != _generation) return;
    if (!_allowed) {
      invalidate(force: true);
      return;
    }
    _requestActive = true;
    _requestId = id;
    emit(AdEventType.request, adUnitId: id);
    var settled = false;
    void loaded(T ad) {
      if (settled) {
        if (!identical(_ad, ad)) _disposeAd(ad);
        return;
      }
      settled = true;
      _requestActive = false;
      if (gen != _generation || !_allowed) {
        _disposeAd(ad);
        if (gen == _generation) invalidate(force: true);
        _resumePending();
        return;
      }
      _ad = ad;
      _loadedId = id;
      _loadedAt = DateTime.now();
      _state = AdState.ready;
      _retryAttempt = 0;
      _retryAfter = null;
      _completeLoad(true);
      notifyListeners();
      emit(AdEventType.loaded, adUnitId: id);
    }

    void failed(LoadAdError error) {
      if (settled) return;
      settled = true;
      _requestActive = false;
      if (gen != _generation) {
        _resumePending();
        return;
      }
      if (!_allowed) {
        invalidate(force: true);
        return;
      }
      _retryAttempt++;
      if (retryPolicy.shouldRetry(_retryAttempt)) {
        _retryTimer?.cancel();
        _retryTimer = Timer(retryPolicy.delayFor(_retryAttempt), () {
          _retryTimer = null;
          _fetch(id, gen);
        });
      } else {
        _retryAfter = DateTime.now().add(retryPolicy.maxDelay);
        _retryAttempt = 0;
        _state = AdState.idle;
        _completeLoad(false);
        notifyListeners();
      }
      emit(AdEventType.loadFailed, adUnitId: id, errorMessage: error.message);
    }

    try {
      requestAd(id, loaded, failed);
    } catch (error) {
      failed(LoadAdError(-1, 'flutter_admob_kit', '$error', null));
    }
  }

  void _resumePending() {
    if (!_reloadPending) return;
    _reloadPending = false;
    final id = _pendingId;
    _pendingId = null;
    final completion = _pendingLoadCompleter;
    _pendingLoadCompleter = null;
    unawaited(
      preload(id).then((result) {
        if (completion != null && !completion.isCompleted) {
          completion.complete(result);
        }
      }),
    );
  }

  void _completePendingLoad(bool result) {
    final completion = _pendingLoadCompleter;
    _pendingLoadCompleter = null;
    if (completion != null && !completion.isCompleted) {
      completion.complete(result);
    }
  }

  @protected
  void setContentCallback(T ad, FullScreenContentCallback<T> callback);

  /// Returns whether the SDK accepted the presentation attempt, not an impression.
  @protected
  Future<bool> present(
    bool shouldShow,
    Future<void> Function(T) show, {
    VoidCallback? onPresentationFailed,
    bool ignoreCooldown = false,
  }) async {
    if (!shouldShow ||
        !_allowed ||
        !canPresentNow ||
        canShowAdsProvider?.call() == false ||
        isShowing ||
        (!ignoreCooldown && isInCooldown)) {
      if (shouldShow) {
        emit(
          AdEventType.skipped,
          reason: !_allowed
              ? _ineligibilityReason
              : !canPresentNow
              ? 'placement_blocked'
              : canShowAdsProvider?.call() == false
              ? 'background'
              : isShowing
              ? 'already_showing'
              : 'cooldown',
        );
      }
      return false;
    }
    emit(AdEventType.opportunity);
    // Event listeners are synchronous and may change route or eligibility.
    // Keep a ready ad cached if the opportunity disappears before ownership.
    if (!_allowed || !canPresentNow || canShowAdsProvider?.call() == false) {
      emit(
        AdEventType.skipped,
        reason: !_allowed
            ? _ineligibilityReason
            : !canPresentNow
            ? 'placement_blocked'
            : 'background',
      );
      return false;
    }
    if (isLoading) {
      emit(AdEventType.cacheMiss, reason: 'loading');
      emit(AdEventType.skipped, reason: 'loading');
      return false;
    }
    if (!isReady || _ad == null) {
      final unavailableReason = isExpired && _ad != null
          ? 'expired'
          : 'unavailable';
      emit(AdEventType.cacheMiss, reason: unavailableReason);
      emit(
        AdEventType.skipped,
        reason: unavailableReason == 'expired'
            ? 'expired_cache'
            : 'unavailable_cache',
      );
      unawaited(preload());
      return false;
    }
    final ad = _ad!;
    final id = _loadedId;
    final token = AdOrchestrator.instance.acquireToken(
      format == AdFormat.appOpen ? 'app_open' : format.name,
    );
    if (token == null) {
      emit(AdEventType.skipped, reason: 'active_fullscreen');
      return false;
    }
    if (!identical(_ad, ad) || !isReady || !_allowed) {
      AdOrchestrator.instance.releaseWithToken(token);
      return false;
    }
    emit(AdEventType.cacheHit, reason: 'presentation');
    _leaseToken = token;
    _state = AdState.showing;
    var closed = false;
    var failedPresentation = false;
    void close({String? error}) {
      if (closed) return;
      closed = true;
      if (error != null) {
        failedPresentation = true;
        emit(AdEventType.presentationFailed, adUnitId: id, errorMessage: error);
        try {
          onPresentationFailed?.call();
        } catch (callbackError) {
          debugPrint(
            'flutter_admob_kit: presentation failure callback failed: $callbackError',
          );
        }
      }
      AdOrchestrator.instance.releaseWithToken(token);
      if (_leaseToken == token) _leaseToken = null;
      _disposeAd(ad);
      if (identical(_ad, ad)) {
        _ad = null;
        _loadedAt = null;
        _loadedId = null;
      }
      if (_state == AdState.disposed) return;
      _state = AdState.idle;
      notifyListeners();
      emit(AdEventType.dismissed, adUnitId: id, errorMessage: error);
      unawaited(preload());
    }

    try {
      setContentCallback(
        ad,
        FullScreenContentCallback<T>(
          onAdShowedFullScreenContent: (_) {
            if (closed || _state == AdState.disposed) return;
            _lastShownAt = DateTime.now();
            emit(AdEventType.shown, adUnitId: id);
          },
          onAdDismissedFullScreenContent: (_) => close(),
          onAdFailedToShowFullScreenContent: (_, error) =>
              close(error: error.message),
          onAdClicked: (_) {
            if (!closed) emit(AdEventType.clicked, adUnitId: id);
          },
          onAdImpression: (_) {
            if (!closed) emit(AdEventType.impression, adUnitId: id);
          },
        ),
      );
    } catch (error) {
      close(error: '$error');
      return false;
    }
    notifyListeners();
    // A listener can synchronously revoke eligibility during the transition.
    if (!_allowed || !canPresentNow || canShowAdsProvider?.call() == false) {
      close(error: 'presentation eligibility changed');
      return false;
    }
    try {
      await show(ad);
      if (failedPresentation) return false;
      emit(AdEventType.presentationAccepted, adUnitId: id);
      return true;
    } catch (error) {
      close(error: '$error');
      return false;
    }
  }

  void _completeLoad(bool result) {
    final completion = _loadCompleter;
    _loadCompleter = null;
    if (completion != null && !completion.isCompleted) {
      completion.complete(result);
    }
  }

  void invalidate({String? newAdUnitId, bool force = false}) {
    if (_state == AdState.disposed) return;
    if (!force && newAdUnitId != null && _loadedId == newAdUnitId && isReady) {
      return;
    }
    if (_ad != null && !isShowing) {
      emit(AdEventType.invalidated, reason: 'configuration_or_eligibility');
    }
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _retryAfter = null;
    _reloadPending = false;
    _pendingId = null;
    _completePendingLoad(false);
    _completeLoad(false);
    // A presented ad and its lease belong to its closing callback, even if
    // consent, entitlement or configuration changes while it is on screen.
    if (isShowing) return;
    _disposeCached();
    _state = AdState.idle;
    notifyListeners();
  }

  void _disposeCached() {
    final ad = _ad;
    _ad = null;
    _loadedAt = null;
    _loadedId = null;
    if (ad != null) _disposeAd(ad);
  }

  void _disposeAd(T ad) {
    unawaited(
      ad.dispose().catchError((Object error) {
        debugPrint('flutter_admob_kit: dispose failed: $error');
      }),
    );
  }

  @protected
  void emit(
    AdEventType type, {
    String? adUnitId,
    String? errorMessage,
    num? rewardAmount,
    String? rewardType,
    String? reason,
  }) {
    if (_state == AdState.disposed) return;
    try {
      onEvent?.call(
        AdEvent(
          format: format,
          type: type,
          timestamp: DateTime.now(),
          adUnitId: adUnitId ?? _loadedId,
          errorMessage: errorMessage,
          rewardAmount: rewardAmount,
          rewardType: rewardType,
          reason: reason,
        ),
      );
    } catch (error) {
      debugPrint('flutter_admob_kit: event listener failed: $error');
    }
  }

  @override
  void dispose() {
    if (_state == AdState.disposed) return;
    final showing = isShowing;
    _generation++;
    _retryTimer?.cancel();
    _reloadPending = false;
    _pendingId = null;
    _completePendingLoad(false);
    _completeLoad(false);
    _state = AdState.disposed;
    if (!showing) _disposeCached();
    super.dispose();
  }

  @visibleForTesting
  int? get leaseToken => _leaseToken;

  @visibleForTesting
  void setAdForTesting(T ad) {
    _ad = ad;
    _loadedId = adUnitIdProvider?.call();
    _loadedAt = DateTime.now();
    _state = AdState.ready;
  }
}
