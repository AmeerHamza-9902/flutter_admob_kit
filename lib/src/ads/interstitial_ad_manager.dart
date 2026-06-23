import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages interstitial ads with expiry handling and retry logic.
///
/// Equivalent to Swift's `InterstitialViewModel`.
///
/// ```dart
/// final vm = InterstitialAdManager();
/// vm.onAdDismissed = () => Navigator.pushNamed(context, '/home');
/// await vm.loadAd('ca-app-pub-XXXX/XXXX');
/// vm.showAd();
/// ```
class InterstitialAdManager extends ChangeNotifier {
  static const int _maxRetries = 3;
  static const Duration _adExpiry = Duration(hours: 1);

  InterstitialAd? _ad;
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _disposed = false;
  int _retryCount = 0;
  int _clickCount = 0;
  DateTime? _loadedAt;

  /// Whether an ad is loaded and not expired.
  bool get isAdReady => _isLoaded && !_isExpired;

  /// Whether an ad is currently loading.
  bool get isLoading => _isLoading;

  /// Fires when the ad loads successfully.
  VoidCallback? onAdLoadComplete;

  /// Fires when the ad fails to load after all retries.
  VoidCallback? onAdLoadFailed;

  /// Fires just before the ad dismisses.
  VoidCallback? onAdDismiss;

  /// Fires after the ad fully dismisses.
  ///
  /// Use this for navigation or post-ad logic.
  VoidCallback? onAdDismissed;

  /// Fires when the ad is clicked.
  VoidCallback? onAdClicked;

  /// Fires when an impression is recorded.
  VoidCallback? onAdImpression;

  bool get _isExpired {
    if (_loadedAt == null) return true;
    return DateTime.now().difference(_loadedAt!) > _adExpiry;
  }

  /// Loads an interstitial ad. Safe to call multiple times.
  ///
  /// Retries up to 3 times on failure with exponential backoff.
  Future<void> loadAd(String adUnitId) async {
    if (_disposed) return;
    if (_isLoaded && _isExpired) {
      _ad?.dispose();
      _ad = null;
      _isLoaded = false;
    }
    if (_isLoading || _isLoaded) return;
    _isLoading = true;
    notifyListeners();
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _ad = ad;
          _isLoaded = true;
          _isLoading = false;
          _retryCount = 0;
          _loadedAt = DateTime.now();
          notifyListeners();
          onAdLoadComplete?.call();
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (_disposed) return;
          _isLoaded = false;
          _isLoading = false;
          notifyListeners();
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(
              Duration(seconds: _retryCount * 2),
              () {
                if (!_disposed) loadAd(adUnitId);
              },
            );
          } else {
            _retryCount = 0;
            onAdLoadFailed?.call();
          }
        },
      ),
    );
  }

  /// Shows the ad immediately.
  ///
  /// Returns `true` if shown, `false` if not ready.
  bool showAd() {
    if (_disposed) return false;
    if (!isAdReady || _ad == null) return false;
    _ad!.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdWillDismissFullScreenContent: (_) => onAdDismiss?.call(),
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        _onAdClosed(ad);
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        _onAdClosed(ad);
        onAdDismissed?.call();
      },
      onAdClicked: (_) => onAdClicked?.call(),
      onAdImpression: (_) => onAdImpression?.call(),
    );
    _ad!.show();
    return true;
  }

  /// Shows after [threshold] taps — for bottom nav or general click events.
  ///
  /// Returns `true` when the ad is actually shown.
  bool onClickEvent(String adUnitId, {int threshold = 3}) {
    if (_disposed) return false;
    _clickCount++;
    if (_clickCount >= threshold) {
      if (showAd()) return true;
      _clickCount = 0;
      loadAd(adUnitId);
    } else if (!isAdReady && !_isLoading) {
      loadAd(adUnitId);
    }
    return false;
  }

  void _onAdClosed(InterstitialAd ad) {
    if (_disposed) {
      ad.dispose();
      return;
    }
    ad.dispose();
    _ad = null;
    _isLoaded = false;
    _clickCount = 0;
    _loadedAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    super.dispose();
  }
}
