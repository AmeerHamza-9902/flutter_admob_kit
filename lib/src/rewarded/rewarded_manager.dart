import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_state.dart';
import '../fullscreen_manager.dart';

/// Owns one rewarded cache and one request at a time.
class RewardedManager extends FullscreenManager<RewardedAd> {
  RewardedManager({
    super.adUnitIdProvider,
    super.isEntitledProvider,
    super.canRequestAdsProvider,
    super.canShowAdsProvider,
    super.adExpiry = const Duration(hours: 1),
    super.cooldown = const Duration(seconds: 0),
    super.retryPolicy,
    super.readinessTimeout,
  }) : super(format: AdFormat.rewarded);

  @protected
  void fetchAd(String adUnitId, RewardedAdLoadCallback callback) {
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: callback,
    ).catchError((Object error) {
      callback.onAdFailedToLoad(LoadAdError(-1, 'platform', '$error', null));
    });
  }

  @override
  void requestAd(
    String id,
    void Function(RewardedAd) loaded,
    void Function(LoadAdError) failed,
  ) {
    fetchAd(
      id,
      RewardedAdLoadCallback(onAdLoaded: loaded, onAdFailedToLoad: failed),
    );
  }

  @override
  void setContentCallback(
    RewardedAd ad,
    FullScreenContentCallback<RewardedAd> callback,
  ) {
    ad.fullScreenContentCallback = callback;
  }

  Future<bool> show(
    bool shouldShow, {
    void Function(RewardItem reward)? onReward,
  }) {
    var rewarded = false;
    var eligible = true;
    return present(
      shouldShow,
      (ad) => ad.show(
        onUserEarnedReward: (_, reward) {
          if (rewarded || !eligible || state == AdState.disposed) return;
          rewarded = true;
          emit(
            AdEventType.rewardEarned,
            rewardAmount: reward.amount,
            rewardType: reward.type,
          );
          onReward?.call(reward);
        },
      ),
      onPresentationFailed: () => eligible = false,
    );
  }
}
