import 'dart:async';

import 'package:flutter/foundation.dart';

/// Mixin that provides the common ad lifecycle logic shared across all
/// fullscreen ad managers: load → retry → expiry → dispose.
///
/// Concrete managers mix this in and only implement [fetchAd] and
/// format-specific show logic.
mixin AdLifecycleMixin on ChangeNotifier {
  static const int defaultMaxRetries = 3;

  int _maxRetries = defaultMaxRetries;
  Duration _adExpiry = const Duration(hours: 1);
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _disposed = false;
  int _retryCount = 0;
  DateTime? _loadedAt;
  Completer<bool>? _loadCompleter;

  /// Whether an ad is loaded and not expired.
  bool get isAdReady => _isLoaded && !isExpired;

  /// Whether an ad is currently loading.
  bool get isLoading => _isLoading;

  /// Whether the manager has been disposed.
  bool get isDisposed => _disposed;

  /// Whether the cached ad has exceeded its maximum freshness lifespan.
  bool get isExpired {
    if (_loadedAt == null) return true;
    return DateTime.now().difference(_loadedAt!) > _adExpiry;
  }

  /// The timestamp when the ad was loaded, or `null` if not loaded.
  DateTime? get loadedAt => _loadedAt;

  /// Override in concrete classes to set a custom max retry count.
  set maxRetries(int value) => _maxRetries = value;

  /// Override in concrete classes to set a custom ad expiry duration.
  set adExpiry(Duration value) => _adExpiry = value;

  /// Loads an ad. Safe to call multiple times.
  ///
  /// Returns `true` when the ad successfully loads, or `false` on failure.
  /// Uses [Completer] to properly await the asynchronous Google SDK callback.
  Future<bool> loadAd(String adUnitId) async {
    if (_disposed) return false;

    // Evict expired ads.
    if (_isLoaded && isExpired) {
      disposeCurrentAd();
      _isLoaded = false;
    }

    // Already loaded and fresh.
    if (_isLoaded && hasActiveAd) return true;

    // Already loading — await the in-flight request.
    if (_isLoading) {
      return _loadCompleter?.future ?? Future.value(false);
    }

    _isLoading = true;
    _retryCount = 0;
    _loadCompleter = Completer<bool>();
    notifyListeners();
    fetchAd(adUnitId);
    return _loadCompleter!.future;
  }

  /// Subclasses must implement this to call the format-specific
  /// `Ad.load()` method (e.g. `InterstitialAd.load()`).
  ///
  /// On success, call [onAdLoadSuccess].
  /// On failure, call [onAdLoadFailure].
  @protected
  void fetchAd(String adUnitId);

  /// Whether the concrete manager currently holds an active ad reference.
  @protected
  bool get hasActiveAd;

  /// Disposes the currently held ad reference.
  @protected
  void disposeCurrentAd();

  /// Called by subclasses when the SDK reports a successful ad load.
  @protected
  void onAdLoadSuccess() {
    if (_disposed) return;
    _isLoaded = true;
    _isLoading = false;
    _retryCount = 0;
    _loadedAt = DateTime.now();
    notifyListeners();
    completeLoad(true);
  }

  /// Called by subclasses when the SDK reports a load failure.
  ///
  /// Retries up to [_maxRetries] times with exponential backoff (2s, 4s, 6s).
  @protected
  void onAdLoadFailure(String adUnitId) {
    if (_disposed) {
      completeLoad(false);
      return;
    }
    if (_retryCount < _maxRetries) {
      _retryCount++;
      Future.delayed(
        Duration(seconds: _retryCount * 2),
        () {
          if (!_disposed) fetchAd(adUnitId);
        },
      );
    } else {
      _retryCount = 0;
      _isLoaded = false;
      _isLoading = false;
      notifyListeners();
      completeLoad(false);
    }
  }

  /// Safely completes the load [Completer].
  @protected
  void completeLoad(bool success) {
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      _loadCompleter!.complete(success);
    }
  }

  /// Resets internal lifecycle state. Call from subclass `dispose()`.
  @protected
  void disposeLifecycle() {
    _disposed = true;
    completeLoad(false);
  }

  /// Marks the ad as consumed after showing.
  @protected
  void markConsumed() {
    _isLoaded = false;
    _loadedAt = null;
    notifyListeners();
  }
}
