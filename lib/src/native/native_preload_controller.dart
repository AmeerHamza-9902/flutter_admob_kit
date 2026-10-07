import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_state.dart';
import '../admob_kit.dart';
import 'native_templates.dart';

/// Owns one short-lived native ad for an upcoming, known placement.
///
/// Create a separate controller for each destination placement. A native ad
/// can be handed to only one [NativeAdWidget].
class NativePreloadController {
  NativePreloadController() {
    AdMobKit.configNotifier.addListener(_configurationChanged);
  }

  static const _templates = MethodChannel('flutter_admob_kit/native_templates');
  _PendingNative? _pending;
  bool _disposed = false;

  Future<bool> preloadMediumNative({
    String? adUnitId,
    NativeAdStyle style = const NativeAdStyle(),
  }) => preload(
    template: NativeTemplate.mediumNative,
    adUnitId: adUnitId,
    style: style,
  );

  Future<bool> preloadBigNative({
    String? adUnitId,
    NativeAdStyle style = const NativeAdStyle(),
  }) => preload(
    template: NativeTemplate.bigNative,
    adUnitId: adUnitId,
    style: style,
  );

  Future<bool> preload({
    required NativeTemplate template,
    String? adUnitId,
    NativeAdStyle style = const NativeAdStyle(),
  }) async {
    if (_disposed || !AdMobKit.canRequestAds) return false;
    final unit = adUnitId ?? AdMobKit.config.nativeId;
    if (unit == null || unit.isEmpty) return false;
    final existing = _pending;
    if (existing != null && existing.matches(template, style, unit)) {
      return await existing.ready.future != null;
    }
    clear();

    final customTemplate =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        template != NativeTemplate.small;
    if (customTemplate) {
      try {
        await _templates.invokeMethod<void>('ensureRegistered');
      } catch (_) {
        return false;
      }
    }
    if (_disposed || !AdMobKit.canRequestAds) return false;

    final entry = _PendingNative(
      template,
      style,
      unit,
      AdMobKit.config.nativeId,
      AdMobKit.config.testMode,
    );
    _pending = entry;

    void fail([NativeAd? ad]) {
      if (!entry.valid) return;
      entry.valid = false;
      entry.timer?.cancel();
      (ad ?? entry.ad)?.dispose();
      if (!entry.ready.isCompleted) entry.ready.complete(null);
      if (identical(_pending, entry)) _pending = null;
    }

    void report(AdEventType type) {
      if (entry.valid && AdMobKit.canRequestAds) {
        AdMobKit.reportEvent(
          AdEvent(
            format: AdFormat.native,
            type: type,
            timestamp: DateTime.now(),
            adUnitId: unit,
          ),
        );
      }
    }

    final ad = NativeAd(
      adUnitId: unit,
      nativeTemplateStyle: customTemplate
          ? null
          : style.toGoogleTemplateStyle(template),
      factoryId: customTemplate
          ? template == NativeTemplate.mediumNative
                ? 'flutter_admob_kit/medium_native'
                : 'flutter_admob_kit/big_native'
          : null,
      customOptions: customTemplate ? style.toNativeOptions() : null,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!entry.valid || !AdMobKit.canRequestAds) {
            fail(ad as NativeAd);
            return;
          }
          report(AdEventType.loaded);
          if (!entry.ready.isCompleted) entry.ready.complete(ad as NativeAd);
          entry.timer?.cancel();
          if (!entry.claimed) {
            entry.timer = Timer(const Duration(minutes: 2), fail);
          }
        },
        onAdFailedToLoad: (ad, _) => fail(ad as NativeAd),
        onAdImpression: (_) => report(AdEventType.impression),
        onAdClicked: (_) => report(AdEventType.clicked),
      ),
    );
    entry.ad = ad;
    entry.timer = Timer(const Duration(minutes: 1), fail);
    try {
      await ad.load();
    } catch (_) {
      fail(ad);
    }
    return await entry.ready.future != null;
  }

  Future<({NativeAd ad, void Function() release})?> take({
    required NativeTemplate template,
    required NativeAdStyle style,
    required String unit,
    Object? owner,
  }) async {
    final entry = _pending;
    if (_disposed || entry == null || entry.claimed) return null;
    if (!entry.matches(template, style, unit)) {
      clear();
      return null;
    }
    entry.claimed = true;
    entry.owner = owner;
    final ad = await entry.ready.future;
    if (identical(_pending, entry)) _pending = null;
    entry.timer?.cancel();
    if (ad == null || !entry.valid || !AdMobKit.canRequestAds) return null;
    return (ad: ad, release: () => entry.valid = false);
  }

  void cancelClaim(Object owner) {
    if (_pending?.claimed == true && identical(_pending?.owner, owner)) clear();
  }

  void _configurationChanged() {
    final entry = _pending;
    if (entry != null &&
        (!AdMobKit.canRequestAds ||
            entry.testMode != AdMobKit.config.testMode ||
            entry.configuredUnit != AdMobKit.config.nativeId)) {
      clear();
    }
  }

  void clear() {
    final entry = _pending;
    _pending = null;
    if (entry == null) return;
    entry.valid = false;
    entry.timer?.cancel();
    entry.ad?.dispose();
    if (!entry.ready.isCompleted) entry.ready.complete(null);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    AdMobKit.configNotifier.removeListener(_configurationChanged);
    clear();
  }
}

class _PendingNative {
  _PendingNative(
    this.template,
    this.style,
    this.unit,
    this.configuredUnit,
    this.testMode,
  );
  final NativeTemplate template;
  final NativeAdStyle style;
  final String unit;
  final String? configuredUnit;
  final bool testMode;
  final ready = Completer<NativeAd?>();
  NativeAd? ad;
  Object? owner;
  Timer? timer;
  bool valid = true;
  bool claimed = false;

  bool matches(
    NativeTemplate target,
    NativeAdStyle targetStyle,
    String targetUnit,
  ) =>
      valid &&
      template == target &&
      style == targetStyle &&
      unit == targetUnit &&
      testMode == AdMobKit.config.testMode;
}
