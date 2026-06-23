import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages App Open ads with expiry handling and paywall guard.
///
/// Equivalent to Swift's `AppOpenAdManager`.
///
/// ```dart
/// final vm = AppOpenAdManager();
/// vm.onAdDismissed = () => navigateToHome();
/// await vm.loadAd('ca-app-pub-XXXX/XXXX');
/// vm.showAdIfAvailable('ca-app-pub-XXXX/XXXX');
/// ```
///
/// Prevent ads on paywall screens:
/// ```dart
/// AppOpenAdManager.isInProScreen = true;  // on appear
/// AppOpenAdManager.isInProScreen = false; // on disappear
/// ```
class AppOpenAdManager extends ChangeNotifier {
  static const int _maxRetries = 3;
  static const Duration _adExpiry = Duration(hours: 4);

  AppOpenAd? _ad;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  bool _disposed = false;
  int _retryCount = 0;
  DateTime? _loadedAt;

  /// Whether an ad is ready and not expired.
  bool get isAdReady => _ad != null && !_isExpired;

  /// Whether an ad is currently loading.
  bool get isLoadingAd => _isLoadingAd;

  /// Whether an ad is currently showing.
  bool get isShowingAd => _isShowingAd;

  /// Set to `true` on paywall screen appear, `false` on disappear.
  ///
  /// Prevents App Open ads from interrupting purchase flows.
  static bool isInProScreen = false;

  /// Fires when the ad loads successfully.
  VoidCallback? onAdLoadComplete;

  /// Fires when the ad fails to load after all retries.
  VoidCallback? onAdLoadFailed;

  /// Fires just before the ad dismisses.
  VoidCallback? onAdDismiss;

  /// Fires after the ad fully dismisses.
  ///
  /// Use this for navigation.
  VoidCallback? onAdDismissed;

  /// Fires when the ad is clicked.
  VoidCallback? onAdClicked;

  /// Fires when an impression is recorded.
  VoidCallback? onAdImpression;

  bool get _isExpired {
    if (_loadedAt == null) return true;
    return DateTime.now().difference(_loadedAt!) > _adExpiry;
  }

  /// Loads an App Open ad. Safe to call multiple times.
  Future<void> loadAd(String adUnitId) async {
    if (_disposed) return;
    if (_ad != null && _isExpired) {
      _ad?.dispose();
      _ad = null;
    }
    if (_isLoadingAd || _ad != null) return;
    _isLoadingAd = true;
    notifyListeners();
    await AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _ad = ad;
          _isLoadingAd = false;
          _retryCount = 0;
          _loadedAt = DateTime.now();
          notifyListeners();
          onAdLoadComplete?.call();
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (_disposed) return;
          _isLoadingAd = false;
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

  /// Shows the ad if available and not on a paywall screen.
  ///
  /// Returns `true` if shown.
  bool showAdIfAvailable(String adUnitId) {
    if (_disposed) return false;
    if (isInProScreen || _isShowingAd || !isAdReady || _ad == null) {
      return false;
    }
    _isShowingAd = true;
    notifyListeners();
    _ad!.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdWillDismissFullScreenContent: (_) => onAdDismiss?.call(),
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        if (_disposed) {
          ad.dispose();
          return;
        }
        ad.dispose();
        _ad = null;
        _isShowingAd = false;
        _loadedAt = null;
        notifyListeners();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        if (_disposed) {
          ad.dispose();
          return;
        }
        ad.dispose();
        _ad = null;
        _isShowingAd = false;
        _loadedAt = null;
        notifyListeners();
        onAdDismissed?.call();
      },
      onAdClicked: (_) => onAdClicked?.call(),
      onAdImpression: (_) => onAdImpression?.call(),
    );
    _ad!.show();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    super.dispose();
  }
}
