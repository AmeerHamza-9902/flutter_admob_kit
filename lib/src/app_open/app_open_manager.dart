import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_state.dart';
import '../fullscreen_manager.dart';

/// Owns one appOpen cache and one request at a time.
class AppOpenManager extends FullscreenManager<AppOpenAd> {
  AppOpenManager({
    super.adUnitIdProvider,
    super.isEntitledProvider,
    super.canRequestAdsProvider,
    super.canShowAdsProvider,
    super.adExpiry = const Duration(hours: 4),
    super.cooldown = const Duration(seconds: 10),
    super.retryPolicy,
  }) : super(format: AdFormat.appOpen);

  bool _manualPaywall = false;
  int _paywallCount = 0;
  bool get isInPaywall => _manualPaywall || _paywallCount > 0;
  set isInPaywall(bool value) => _manualPaywall = value;
  void enterPaywall() => _paywallCount++;
  void leavePaywall() {
    if (_paywallCount > 0) _paywallCount--;
  }

  @protected
  void fetchAd(String adUnitId, AppOpenAdLoadCallback callback) {
    AppOpenAd.load(
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
    void Function(AppOpenAd) loaded,
    void Function(LoadAdError) failed,
  ) {
    fetchAd(
      id,
      AppOpenAdLoadCallback(onAdLoaded: loaded, onAdFailedToLoad: failed),
    );
  }

  @override
  void setContentCallback(
    AppOpenAd ad,
    FullScreenContentCallback<AppOpenAd> callback,
  ) {
    ad.fullScreenContentCallback = callback;
  }

  Future<bool> show([bool shouldShow = true]) =>
      present(shouldShow && !isInPaywall, (ad) => ad.show());
}
