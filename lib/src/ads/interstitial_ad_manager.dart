// lib/ads/interstitial_ad_manager.dart

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdManager {
  InterstitialAdManager._();
  static final instance = InterstitialAdManager._();

  final _counters = <String, int>{};
  final _cache = <String, InterstitialAd?>{};

  /// Threshold-based: increments counter; shows ad when threshold is reached.
  void onClickEvent(
    BuildContext context,
    String adUnitId,
    int threshold,
    String slotKey,
  ) {
    final count = (_counters[slotKey] ?? 0) + 1;
    _counters[slotKey] = count;
    if (count >= threshold) {
      _counters[slotKey] = 0;
      showNow(context, adUnitId);
    } else {
      _preload(adUnitId, slotKey);
    }
  }

  /// Show immediately (no threshold), returns a Future that resolves on dismiss.
  Future<void> showNow(BuildContext context, String adUnitId) {
    final completer = _AdCompleter();
    final cached = _cache[adUnitId];
    if (cached != null) {
      _cache[adUnitId] = null;
      _attachAndShow(cached, adUnitId, completer);
    } else {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _attachAndShow(ad, adUnitId, completer),
          onAdFailedToLoad: (err) => completer._complete(),
        ),
      );
    }
    return completer.future;
  }

  void _attachAndShow(InterstitialAd ad, String adUnitId, _AdCompleter completer) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        completer._complete();
        _preload(adUnitId, adUnitId);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        completer._complete();
      },
    );
    ad.show();
  }

  void _preload(String adUnitId, String cacheKey) {
    if (_cache[cacheKey] != null) return;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _cache[cacheKey] = ad,
        onAdFailedToLoad: (_) => _cache[cacheKey] = null,
      ),
    );
  }
}

class _AdCompleter {
  final _completer = Future<void>.value();
  void Function()? _resolve;
  late final future = Future<void>(() async {
    await Future.delayed(Duration.zero);
  });
  void _complete() {}
}
