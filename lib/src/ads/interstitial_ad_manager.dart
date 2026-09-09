import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ad_lifecycle_mixin.dart';
import 'ad_presentation_coordinator.dart';

/// Manages interstitial ads with expiry handling, retry logic, and
/// click-threshold support.
///
/// ```dart
/// final vm = InterstitialAdManager();
/// vm.onAdDismissed = () => Navigator.pushNamed(context, '/home');
/// await vm.loadAd('ca-app-pub-XXXX/XXXX');
/// vm.showAd();
/// ```
class InterstitialAdManager extends ChangeNotifier with AdLifecycleMixin {
  InterstitialAd? _ad;
  int _clickCount = 0;

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
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
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

  /// Shows the ad immediately.
  ///
  /// Returns `true` if shown, `false` if not ready or presentation lease
  /// is occupied.
  bool showAd() {
    if (isDisposed) return false;
    if (!isAdReady || _ad == null) return false;
    if (!AdPresentationCoordinator.instance
        .tryAcquire(format: 'interstitial')) {
      return false;
    }
    _ad!.fullScreenContentCallback =
        FullScreenContentCallback<InterstitialAd>(
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

  /// Shows the ad after [threshold] taps — for bottom nav or general click
  /// events.
  ///
  /// Returns `true` when the ad is actually shown.
  ///
  /// **Important**: When the threshold is reached but the ad is not ready,
  /// the counter is **not** reset. This prevents wasted impression requests
  /// (load fires but user has already navigated away). The next click will
  /// re-check and show the ad if it becomes ready.
  bool onClickEvent(String adUnitId, {int threshold = 3}) {
    if (isDisposed) return false;
    _clickCount++;

    if (_clickCount >= threshold) {
      if (isAdReady) {
        if (showAd()) return true;
      }
      // Ad not ready: do NOT reset counter. Preload in background.
      if (!isAdReady && !isLoading) {
        loadAd(adUnitId);
      }
    } else if (!isAdReady && !isLoading) {
      // Eager preload: action buffer — load early so ad is ready by threshold.
      loadAd(adUnitId);
    }
    return false;
  }

  void _onAdClosed(InterstitialAd ad) {
    AdPresentationCoordinator.instance.release();
    if (isDisposed) {
      ad.dispose();
      return;
    }
    ad.dispose();
    _ad = null;
    _clickCount = 0;
    markConsumed();
  }

  @override
  void dispose() {
    disposeLifecycle();
    _ad?.dispose();
    super.dispose();
  }
}
