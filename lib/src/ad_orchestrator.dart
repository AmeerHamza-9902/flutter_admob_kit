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

  /// Monotonic presentation generation, including already dismissed ads.
  int get presentationGeneration => _leaseCounter;

  /// Whether any fullscreen ad is currently active on screen.
  bool get isAnyFullscreenShowing => _isLeaseHeld;

  /// The format name currently presenting, or `null` if idle.
  String? get activeFormat => _activeFormat;

  /// Attempts to acquire the presentation lock and returns an ownership token,
  /// or `null` if the lock is already held.
  int? acquireToken(String format) {
    if (_isLeaseHeld) return null;
    _isLeaseHeld = true;
    _activeFormat = format;
    final token = ++_leaseCounter;
    _activeToken = token;
    notifyListeners();
    return token;
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

  /// Resets state (useful for unit tests).
  @visibleForTesting
  void reset() {
    _isLeaseHeld = false;
    _activeFormat = null;
    _activeToken = null;
  }
}
