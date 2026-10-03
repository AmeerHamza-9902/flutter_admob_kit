import 'package:flutter/foundation.dart';

/// Central coordinator that enforces mutual exclusion across fullscreen ad formats.
///
/// Prevents simultaneous or overlapping presentation of Interstitial,
/// Rewarded, and App Open ads.
class AdOrchestrator extends ChangeNotifier {
  AdOrchestrator._();

  static final AdOrchestrator instance = AdOrchestrator._();

  bool _isLeaseHeld = false;
  String? _activeFormat;

  int _leaseCounter = 0;
  int? _activeToken;

  /// Whether any fullscreen ad is currently active on screen.
  bool get isAnyFullscreenShowing => _isLeaseHeld;

  /// The format name currently presenting, or `null` if idle.
  String? get activeFormat => _activeFormat;

  /// Attempts to acquire the presentation lock for [format].
  ///
  /// Returns `true` if acquired, `false` if another fullscreen ad is already presenting.
  bool tryAcquire(String format) {
    if (_isLeaseHeld) return false;
    _isLeaseHeld = true;
    _activeFormat = format;
    _activeToken = ++_leaseCounter;
    notifyListeners();
    return true;
  }

  /// Attempts to acquire the presentation lock and returns an ownership token,
  /// or `null` if the lock is already held.
  int? acquireToken(String format) {
    if (_isLeaseHeld) return null;
    _isLeaseHeld = true;
    _activeFormat = format;
    _activeToken = ++_leaseCounter;
    notifyListeners();
    return _activeToken;
  }

  /// Releases the presentation lock using the [token] obtained from [acquireToken].
  /// Only the true owner of the current lease can release it.
  /// Returns `true` if successfully released, `false` otherwise.
  bool releaseWithToken(int token) {
    if (!_isLeaseHeld || _activeToken != token) return false;
    _isLeaseHeld = false;
    _activeFormat = null;
    _activeToken = null;
    notifyListeners();
    return true;
  }

  /// Releases the presentation lock.
  void release([String? format]) {
    if (!_isLeaseHeld) return;
    if (format != null && _activeFormat != null && _activeFormat != format) {
      return;
    }
    _isLeaseHeld = false;
    _activeFormat = null;
    _activeToken = null;
    notifyListeners();
  }

  /// Resets state (useful for unit tests).
  @visibleForTesting
  void reset() {
    _isLeaseHeld = false;
    _activeFormat = null;
    _activeToken = null;
  }
}
