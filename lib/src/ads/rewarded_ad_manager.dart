import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ad_lifecycle_mixin.dart';
import 'ad_presentation_coordinator.dart';

/// Manages rewarded ads with coin tracking and retry logic.
///
/// ```dart
/// final vm = RewardedAdManager();
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
class RewardedAdManager extends ChangeNotifier with AdLifecycleMixin {
  RewardedAd? _ad;
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
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
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

  /// Shows the rewarded ad. Returns `true` if shown.
  bool showAd() {
    if (isDisposed) return false;
    if (!isAdReady || _ad == null) return false;
    if (!AdPresentationCoordinator.instance
        .tryAcquire(format: 'rewarded')) {
      return false;
    }
    _ad!.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdWillDismissFullScreenContent: (_) => onAdDismiss?.call(),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        _onAdClosed(ad);
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
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

  void _onAdClosed(RewardedAd ad) {
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
