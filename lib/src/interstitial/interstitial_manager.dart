import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_state.dart';
import '../fullscreen_manager.dart';

/// Owns one interstitial cache and one request at a time.
class InterstitialManager extends FullscreenManager<InterstitialAd> {
  InterstitialManager({
    super.adUnitIdProvider,
    super.isEntitledProvider,
    super.canRequestAdsProvider,
    super.canShowAdsProvider,
    super.adExpiry = const Duration(hours: 1),
    super.cooldown = Duration.zero,
    super.retryPolicy,
  }) : super(format: AdFormat.interstitial);

  @protected
  void fetchAd(String adUnitId, InterstitialAdLoadCallback callback) {
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: callback,
    ).catchError((Object error) {
      callback.onAdFailedToLoad(LoadAdError(-1, 'platform', '$error', null));
    });
  }

  @override
  void requestAd(
    String id,
    void Function(InterstitialAd) loaded,
    void Function(LoadAdError) failed,
  ) {
    fetchAd(
      id,
      InterstitialAdLoadCallback(onAdLoaded: loaded, onAdFailedToLoad: failed),
    );
  }

  @override
  void setContentCallback(
    InterstitialAd ad,
    FullScreenContentCallback<InterstitialAd> callback,
  ) {
    ad.fullScreenContentCallback = callback;
  }

  Future<bool> show([
    bool shouldShow = true,
    bool ignoreCooldown = false,
  ]) =>
      present(
        shouldShow,
        (ad) => ad.show(),
        ignoreCooldown: ignoreCooldown,
      );
}
