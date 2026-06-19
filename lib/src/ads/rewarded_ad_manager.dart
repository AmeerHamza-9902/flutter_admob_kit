import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages rewarded ads with coin tracking.
///
/// Equivalent to Swift's `RewardedViewModel`.
///
/// ```dart
/// final vm = RewardedAdManager();
/// vm.onAdDismissed = () { };
/// vm.onCoinsEarned = (coins) => print('Earned: $coins');
/// await vm.loadAd('ca-app-pub-XXXX/XXXX');
/// vm.showAd();
/// ```
///
/// Listen to coin changes:
/// ```dart
/// ListenableBuilder(
///   listenable: vm,
///   builder: (context, _) => Text('Coins: ${vm.coins}'),
/// )
/// ```
class RewardedAdManager extends ChangeNotifier {
  static const int _maxRetries = 3;
  static const Duration _adExpiry = Duration(hours: 1);

  RewardedAd? _ad;
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _disposed = false;
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
  // ignore: avoid_positional_boolean_parameters
  void Function(int coins)? onCoinsEarned;

  bool get _isExpired {
    if (_loadedAt == null) return true;
    return DateTime.now().difference(_loadedAt!) > _adExpiry;
  }

  /// Loads a rewarded ad. Safe to call multiple times.
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
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
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

  /// Shows the rewarded ad. Returns `true` if shown.
  bool showAd() {
    if (_disposed) return false;
    if (!isAdReady || _ad == null) return false;
    _ad!.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdWillDismissFullScreenContent: (_) => onAdDismiss?.call(),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        if (_disposed) {
          ad.dispose();
          return;
        }
        ad.dispose();
        _ad = null;
        _isLoaded = false;
        _loadedAt = null;
        notifyListeners();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        if (_disposed) {
          ad.dispose();
          return;
        }
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
        if (_disposed) return;
        _coins += reward.amount.toInt();
        notifyListeners();
        onCoinsEarned?.call(_coins);
      },
    );
    return true;
  }

  /// Resets the coin counter to zero.
  void resetCoins() {
    if (_disposed) return;
    _coins = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    super.dispose();
  }
}
