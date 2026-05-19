import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages rewarded interstitial ads with coin tracking.
///
/// Equivalent to Swift's `RewardedInterstitialViewModel`.
///
/// Unlike [RewardedAdManager], this shows automatically without a dedicated
/// button — the user can skip but may still earn a reward.
///
/// ```dart
/// final vm = RewardedInterstitialAdManager();
/// vm.onAdDismissed = () { };
/// vm.onCoinsEarned = (coins) => print('Coins: $coins');
/// await vm.loadAd('ca-app-pub-XXXX/XXXX');
/// vm.showAd();
/// ```
class RewardedInterstitialAdManager extends ChangeNotifier {
  static const int _maxRetries = 3;
  static const Duration _adExpiry = Duration(hours: 1);

  RewardedInterstitialAd? _ad;
  bool _isLoading = false;
  bool _isLoaded = false;
  int _retryCount = 0;
  int _coins = 0;
  DateTime? _loadedAt;

  /// Whether an ad is loaded and not expired.
  bool get isAdReady => _isLoaded && !_isExpired;

  /// Whether an ad is currently loading.
  bool get isLoading => _isLoading;

  /// Total coins earned. Listen with [ListenableBuilder].
  int get coins => _coins;

  /// Fires when the ad loads successfully.
  VoidCallback? onAdLoadComplete;

  /// Fires when the ad fails to load after all retries.
  VoidCallback? onAdLoadFailed;

  /// Fires just before the ad dismisses.
  VoidCallback? onAdDismiss;

  /// Fires after the ad fully dismisses.
  VoidCallback? onAdDismissed;

  /// Fires when the user earns a reward, with the updated total.
  void Function(int coins)? onCoinsEarned;

  bool get _isExpired {
    if (_loadedAt == null) return true;
    return DateTime.now().difference(_loadedAt!) > _adExpiry;
  }

  /// Loads a rewarded interstitial ad. Safe to call multiple times.
  Future<void> loadAd(String adUnitId) async {
    if (_isLoaded && _isExpired) {
      _ad?.dispose();
      _ad = null;
      _isLoaded = false;
    }
    if (_isLoading || _isLoaded) return;
    _isLoading = true;
    notifyListeners();
    await RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback:
          RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
          _ad = ad;
          _isLoaded = true;
          _isLoading = false;
          _retryCount = 0;
          _loadedAt = DateTime.now();
          notifyListeners();
          onAdLoadComplete?.call();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isLoaded = false;
          _isLoading = false;
          notifyListeners();
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(
              Duration(seconds: _retryCount * 2),
              () => loadAd(adUnitId),
            );
          } else {
            _retryCount = 0;
            onAdLoadFailed?.call();
          }
        },
      ),
    );
  }

  /// Shows the rewarded interstitial ad. Returns `true` if shown.
  bool showAd() {
    if (!isAdReady || _ad == null) return false;
    _ad!.fullScreenContentCallback =
        FullScreenContentCallback<RewardedInterstitialAd>(
      onAdWillDismissFullScreenContent: (_) => onAdDismiss?.call(),
      onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
        ad.dispose();
        _ad = null;
        _isLoaded = false;
        _loadedAt = null;
        notifyListeners();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent:
          (RewardedInterstitialAd ad, AdError error) {
        ad.dispose();
        _ad = null;
        _isLoaded = false;
        _loadedAt = null;
        notifyListeners();
        onAdDismissed?.call();
      },
    );
    _ad!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _coins += reward.amount.toInt();
        notifyListeners();
        onCoinsEarned?.call(_coins);
      },
    );
    return true;
  }

  /// Resets the coin counter to zero.
  void resetCoins() {
    _coins = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }
}
