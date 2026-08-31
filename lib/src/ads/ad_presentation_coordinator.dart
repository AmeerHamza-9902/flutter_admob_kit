import 'package:flutter/foundation.dart';

/// Coordinates full-screen ad presentations across all formats
/// (App Open, Interstitial, Rewarded, Rewarded Interstitial) to guarantee
/// single-presentation mutual exclusion and prevent overlapping ad collisions.
class AdPresentationCoordinator extends ChangeNotifier {
  AdPresentationCoordinator._();

  /// The global shared singleton instance.
  static final AdPresentationCoordinator instance =
      AdPresentationCoordinator._();

  bool _isLeaseHeld = false;
  String? _activeFormat;

  /// Whether any full-screen ad is currently holding the presentation lease.
  bool get isPresenting => _isLeaseHeld;

  /// The format name currently presenting, or `null` if idle.
  String? get activeFormat => _activeFormat;

  /// Attempts to acquire the presentation lease.
  ///
  /// Returns `true` if the lease was acquired successfully.
  /// Returns `false` if another full-screen ad is already presenting.
  bool tryAcquire({String format = 'fullscreen'}) {
    if (_isLeaseHeld) return false;
    _isLeaseHeld = true;
    _activeFormat = format;
    notifyListeners();
    return true;
  }

  /// Releases the active presentation lease.
  void release() {
    if (!_isLeaseHeld) return;
    _isLeaseHeld = false;
    _activeFormat = null;
    notifyListeners();
  }

  /// Reset coordinator state (useful for tests).
  @visibleForTesting
  void reset() {
    _isLeaseHeld = false;
    _activeFormat = null;
  }
}
