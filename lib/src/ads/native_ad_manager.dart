import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages native ads with automatic reload and expiry handling.
///
/// Equivalent to Swift's `NativeAdViewModel`.
///
/// ```dart
/// final vm = NativeAdManager(adUnitId: 'ca-app-pub-XXXX/XXXX');
/// vm.refreshAd();
///
/// // In build:
/// ListenableBuilder(
///   listenable: vm,
///   builder: (context, _) => NativeAdWidget(manager: vm),
/// )
/// ```
class NativeAdManager extends ChangeNotifier {
  static const int _maxRetries = 3;
  static const Duration _adExpiry = Duration(hours: 1);

  /// The AdMob native ad unit ID.
  final String adUnitId;

  /// The factory ID registered in your platform-specific code.
  final String factoryId;

  NativeAd? _ad;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _disposed = false;
  int _retryCount = 0;
  DateTime? _loadedAt;

  /// The loaded [NativeAd], or `null` if not ready.
  NativeAd? get ad => _ad;

  /// Whether the native ad is ready to display.
  bool get isAdReady => _isLoaded && !_isExpired;

  /// Whether an ad is currently loading.
  bool get isLoading => _isLoading;

  /// Fires when the ad loads successfully.
  VoidCallback? onAdLoaded;

  /// Fires when the ad fails to load after all retries.
  VoidCallback? onAdLoadFailed;

  /// Fires when the ad is clicked.
  VoidCallback? onAdClicked;

  /// Fires when an impression is recorded.
  VoidCallback? onAdImpression;

  /// Creates a [NativeAdManager] for the given [adUnitId].
  NativeAdManager({
    required this.adUnitId,
    this.factoryId = 'adFactory',
  });

  bool get _isExpired {
    if (_loadedAt == null) return true;
    return DateTime.now().difference(_loadedAt!) > _adExpiry;
  }

  /// Loads or refreshes the native ad.
  ///
  /// Equivalent to Swift's `nativeVM.refreshAd()`.
  void refreshAd() {
    if (_disposed) return;
    _ad?.dispose();
    _ad = null;
    _isLoaded = false;
    _isLoading = true;
    _retryCount = 0;
    notifyListeners();
    _load();
  }

  void _load() {
    if (_disposed) return;
    _ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (_disposed) {
            _ad?.dispose();
            _ad = null;
            return;
          }
          _isLoaded = true;
          _isLoading = false;
          _retryCount = 0;
          _loadedAt = DateTime.now();
          notifyListeners();
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          ad.dispose();
          _ad = null;
          _isLoaded = false;
          _isLoading = false;
          notifyListeners();
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(Duration(seconds: _retryCount * 2), () {
              if (!_disposed) _load();
            });
          } else {
            _retryCount = 0;
            onAdLoadFailed?.call();
          }
        },
        onAdClicked: (_) => onAdClicked?.call(),
        onAdImpression: (_) => onAdImpression?.call(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    super.dispose();
  }
}
