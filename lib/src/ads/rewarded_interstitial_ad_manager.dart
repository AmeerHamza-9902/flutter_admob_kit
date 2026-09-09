import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ad_lifecycle_mixin.dart';
import 'ad_presentation_coordinator.dart';

/// Manages rewarded interstitial ads with coin tracking.
///
/// Unlike [RewardedAdManager], this shows automatically without a dedicated
/// button — the user can skip but may still earn a reward.
///
/// ```dart
/// final vm = RewardedInterstitialAdManager();
/// vm.onCoinsEarned = (coins) => print('Coins: $coins');
/// await vm.loadAd('ca-app-pub-XXXX/XXXX');
/// vm.showAd();
/// ```
class RewardedInterstitialAdManager extends ChangeNotifier
    with AdLifecycleMixin {
  RewardedInterstitialAd? _ad;
  int _coins = 0;

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

  /// Fires when the ad is clicked.
  VoidCallback? onAdClicked;

  /// Fires when an impression is recorded.
  VoidCallback? onAdImpression;

  /// Fires when the user earns a reward, with the updated total.
  void Function(int coins)? onCoinsEarned;

  @override
  @protected
  bool get hasActiveAd => _ad != null;

  @override
  @protected
  void disposeCurrentAd() {
    _ad?.dispose();
    _ad = null;
  }

  @override
  @protected
  void fetchAd(String adUnitId) {
    if (isDisposed) {
      completeLoad(false);
      return;
    }
    RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
          if (isDisposed) {
            ad.dispose();
            completeLoad(false);
            return;
          }
          _ad = ad;
          onAdLoadSuccess();
          onAdLoadComplete?.call();
        },
        onAdFailedToLoad: (LoadAdError error) {
          onAdLoadFailure(adUnitId);
          if (!isLoading) {
            onAdLoadFailed?.call();
          }
        },
      ),
    );
  }

  /// Shows the rewarded interstitial ad. Returns `true` if shown.
  bool showAd() {
    if (isDisposed) return false;
    if (!isAdReady || _ad == null) return false;
    if (!AdPresentationCoordinator.instance
        .tryAcquire(format: 'rewarded_interstitial')) {
      return false;
    }
    _ad!.fullScreenContentCallback =
        FullScreenContentCallback<RewardedInterstitialAd>(
      onAdWillDismissFullScreenContent: (_) => onAdDismiss?.call(),
      onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
        _onAdClosed(ad);
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent:
          (RewardedInterstitialAd ad, AdError error) {
        _onAdClosed(ad);
        onAdDismissed?.call();
      },
      onAdClicked: (_) => onAdClicked?.call(),
      onAdImpression: (_) => onAdImpression?.call(),
    );
    _ad!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        if (isDisposed) return;
        _coins += reward.amount.toInt();
        notifyListeners();
        onCoinsEarned?.call(_coins);
      },
    );
    return true;
  }

  /// Resets the coin counter to zero.
  void resetCoins() {
    if (isDisposed) return;
    _coins = 0;
    notifyListeners();
  }

  void _onAdClosed(RewardedInterstitialAd ad) {
    AdPresentationCoordinator.instance.release();
    if (isDisposed) {
      ad.dispose();
      return;
    }
    ad.dispose();
    _ad = null;
    markConsumed();
  }

  @override
  void dispose() {
    disposeLifecycle();
    _ad?.dispose();
    super.dispose();
  }
}
