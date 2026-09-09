import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ad_lifecycle_mixin.dart';
import 'ad_presentation_coordinator.dart';

/// Manages App Open ads with expiry handling, retry logic, and paywall guard.
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
class AppOpenAdManager extends ChangeNotifier with AdLifecycleMixin {
  AppOpenAdManager() {
    adExpiry = const Duration(hours: 4);
  }

  AppOpenAd? _ad;
  bool _isShowingAd = false;

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
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
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

  /// Shows the ad if available, not expired, not on paywall, and presentation
  /// lease is free.
  ///
  /// Returns `true` if shown.
  bool showAdIfAvailable(String adUnitId) {
    if (isDisposed) return false;
    if (isInProScreen || _isShowingAd) return false;
    if (!isAdReady || _ad == null) return false;

    // Freshness validation — evict expired ads silently.
    if (isExpired) {
      disposeCurrentAd();
      markConsumed();
      return false;
    }

    if (!AdPresentationCoordinator.instance
        .tryAcquire(format: 'app_open')) {
      return false;
    }

    _isShowingAd = true;
    notifyListeners();
    _ad!.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdWillDismissFullScreenContent: (_) => onAdDismiss?.call(),
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        _onAdClosed(ad);
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        _onAdClosed(ad);
        onAdDismissed?.call();
      },
      onAdClicked: (_) => onAdClicked?.call(),
      onAdImpression: (_) => onAdImpression?.call(),
    );
    _ad!.show();
    return true;
  }

  void _onAdClosed(AppOpenAd ad) {
    AdPresentationCoordinator.instance.release();
    if (isDisposed) {
      ad.dispose();
      return;
    }
    ad.dispose();
    _ad = null;
    _isShowingAd = false;
    markConsumed();
  }

  @override
  void dispose() {
    if (_isShowingAd) {
      AdPresentationCoordinator.instance.release();
    }
    disposeLifecycle();
    _ad?.dispose();
    super.dispose();
  }
}
