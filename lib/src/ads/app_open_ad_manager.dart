// lib/ads/app_open_ad_manager.dart

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdManager {
  AppOpenAdManager._();
  static final instance = AppOpenAdManager._();

  AppOpenAd? _cachedAd;
  bool _isShowing = false;

  void preload(String adUnitId) {
    if (_cachedAd != null) return;
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _cachedAd = ad,
        onAdFailedToLoad: (_) => _cachedAd = null,
      ),
    );
  }

  Future<void> show(String adUnitId) async {
    if (_isShowing) return;
    final cached = _cachedAd;
    if (cached != null) {
      _cachedAd = null;
      await _showAd(cached, adUnitId);
    } else {
      await _loadAndShow(adUnitId);
    }
  }

  Future<void> _loadAndShow(String adUnitId) async {
    final completer = _Completer();
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) async {
          await _showAd(ad, adUnitId);
          completer.resolve();
        },
        onAdFailedToLoad: (_) => completer.resolve(),
      ),
    );
    return completer.future;
  }

  Future<void> _showAd(AppOpenAd ad, String adUnitId) async {
    final completer = _Completer();
    _isShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _isShowing = false;
        ad.dispose();
        preload(adUnitId);
        completer.resolve();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        _isShowing = false;
        ad.dispose();
        completer.resolve();
      },
    );
    ad.show();
    return completer.future;
  }
}

class _Completer {
  late final Future<void> future;
  late final void Function() resolve;
  _Completer() {
    late void Function() r;
    future = Future(() {}).then((_) async {
      await Future.delayed(Duration.zero);
    });
    resolve = () {};
  }
}
