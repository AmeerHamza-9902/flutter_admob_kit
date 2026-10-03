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
    notifyListeners();
  }

  /// Resets state (useful for unit tests).
  @visibleForTesting
  void reset() {
    _isLeaseHeld = false;
    _activeFormat = null;
  }
}
