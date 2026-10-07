import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_state.dart';
import '../admob_kit.dart';
import 'banner_manager.dart';

/// Owns one short-lived banner for an upcoming placement.
/// Preload only after initialization/consent, close to the expected navigation.
class BannerPreloadController {
  BannerPreloadController() {
    AdMobKit.configNotifier.addListener(_configurationChanged);
  }

  _PendingBanner? _pending;
  bool _disposed = false;

  Future<bool> preloadLarge({String? adUnitId}) =>
      preload(size: AdSize.largeBanner, adUnitId: adUnitId);

  Future<bool> preloadMediumRectangle({String? adUnitId}) =>
      preload(size: AdSize.mediumRectangle, adUnitId: adUnitId);

  Future<bool> preloadInlineAdaptive({
    required int width,
    int maxHeight = 250,
    String? adUnitId,
  }) {
    if (width <= 0 || maxHeight < 50) {
      throw ArgumentError('Positive width and maxHeight >= 50 are required.');
    }
    return preload(
      size: AdSize.getInlineAdaptiveBannerAdSize(width, maxHeight),
      adUnitId: adUnitId,
    );
  }

  Future<bool> preloadSmall({required int width, String? adUnitId}) async {
    if (width <= 0) throw ArgumentError.value(width, 'width');
    final size = await BannerManager.getAdaptiveSize(width);
    return preload(size: size, adUnitId: adUnitId);
  }

  /// Loads at most one banner. Repeated identical calls share the pending load.
  /// For adaptive banners, pass the size calculated for the destination width.
  Future<bool> preload({required AdSize size, String? adUnitId}) async {
    if (_disposed || !AdMobKit.canRequestAds) return false;
    final unit = adUnitId ?? AdMobKit.config.bannerId;
    if (unit == null || unit.isEmpty) return false;
    final existing = _pending;
    if (existing != null && existing.matches(size, unit)) {
      return await existing.ready.future != null;
    }
    clear();
    final entry = _PendingBanner(size, unit, AdMobKit.config.testMode);
    _pending = entry;
    void fail() {
      if (!entry.valid) return;
      AdMobKit.reportEvent(
        AdEvent(
          format: AdFormat.banner,
          type: entry.loaded ? AdEventType.expired : AdEventType.loadFailed,
          timestamp: DateTime.now(),
          adUnitId: unit,
        ),
      );
      if (!entry.ready.isCompleted) entry.ready.complete(null);
      entry.valid = false;
      entry.timer?.cancel();
      entry.ad?.dispose();
      if (identical(_pending, entry)) _pending = null;
    }

    void report(AdEventType type) {
      if (entry.valid &&
          AdMobKit.canRequestAds &&
          entry.testMode == AdMobKit.config.testMode) {
        AdMobKit.reportEvent(
          AdEvent(
            format: AdFormat.banner,
            type: type,
            timestamp: DateTime.now(),
            adUnitId: unit,
          ),
        );
      }
    }

    final ad = BannerAd(
      adUnitId: unit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          if (entry.loadCallbackActive) {
            if (!identical(ad, entry.ad)) ad.dispose();
            return;
          }
          entry.loadCallbackActive = true;
          if (!entry.valid || !AdMobKit.canRequestAds) {
            if (!identical(ad, entry.ad)) ad.dispose();
            fail();
            return;
          }
          AdSize? actual = size;
          if (size is InlineAdaptiveSize) {
            try {
              actual = await (ad as BannerAd).getPlatformAdSize();
            } catch (_) {
              actual = null;
            }
          }
          if (!entry.valid ||
              !AdMobKit.canRequestAds ||
              actual == null ||
              actual.width <= 0 ||
              actual.height <= 0) {
            fail();
            return;
          }
          entry.actualSize = actual;
          entry.loaded = true;
          report(AdEventType.loaded);
          if (!entry.ready.isCompleted) entry.ready.complete(ad as BannerAd);
          entry.timer?.cancel();
          if (!entry.claimed) {
            entry.timer = Timer(const Duration(minutes: 2), fail);
          }
        },
        onAdFailedToLoad: (_, _) {
          if (!entry.loaded) fail();
        },
        onAdImpression: (_) => report(AdEventType.impression),
        onAdClicked: (_) => report(AdEventType.clicked),
      ),
    );
    entry.ad = ad;
    entry.timer = Timer(const Duration(minutes: 1), fail);
    report(AdEventType.request);
    try {
      await ad.load();
    } catch (_) {
      fail();
    }
    return await entry.ready.future != null;
  }

  /// Bounds only the caller's wait; the pending banner keeps loading.
  Future<bool> waitUntilReady({
    required AdSize size,
    String? adUnitId,
    Duration? timeout,
  }) {
    final limit = timeout ?? AdMobKit.config.adReadinessTimeout;
    if (limit <= Duration.zero) {
      final unit = adUnitId ?? AdMobKit.config.bannerId;
      final entry = _pending;
      return Future.value(
        unit != null &&
            entry != null &&
            entry.loaded &&
            entry.matches(size, unit),
      );
    }
    return preload(size: size, adUnitId: adUnitId).timeout(
      limit,
      onTimeout: () {
        AdMobKit.reportEvent(
          AdEvent(
            format: AdFormat.banner,
            type: AdEventType.waitTimedOut,
            timestamp: DateTime.now(),
            adUnitId: adUnitId ?? AdMobKit.config.bannerId,
            reason: 'readiness_timeout',
          ),
        );
        return false;
      },
    );
  }

  /// Internal handoff: a loaded/pending ad can belong to only one widget.
  Future<({BannerAd ad, AdSize size, void Function() release})?> take(
    AdSize size,
    String unit, {
    Object? owner,
  }) async {
    final entry = _pending;
    if (_disposed || entry == null || entry.claimed) {
      AdMobKit.reportEvent(
        AdEvent(
          format: AdFormat.banner,
          type: AdEventType.cacheMiss,
          timestamp: DateTime.now(),
          adUnitId: unit,
        ),
      );
      return null;
    }
    if (!entry.matches(size, unit)) {
      clear();
      return null;
    }
    entry.claimed = true;
    entry.owner = owner;
    final ad = await entry.ready.future;
    if (identical(_pending, entry)) _pending = null;
    entry.timer?.cancel();
    if (ad == null || !entry.valid || !AdMobKit.canRequestAds) return null;
    AdMobKit.reportEvent(
      AdEvent(
        format: AdFormat.banner,
        type: AdEventType.cacheHit,
        timestamp: DateTime.now(),
        adUnitId: unit,
      ),
    );
    return (
      ad: ad,
      size: entry.actualSize!,
      release: () => entry.valid = false,
    );
  }

  /// Cancels only the pending handoff owned by the departing widget.
  void cancelClaim(Object owner) {
    if (_pending?.claimed == true && identical(_pending?.owner, owner)) clear();
  }

  void _configurationChanged() {
    final entry = _pending;
    if (entry != null &&
        (!AdMobKit.canRequestAds ||
            entry.testMode != AdMobKit.config.testMode ||
            entry.configuredUnit != AdMobKit.config.bannerId)) {
      clear();
    }
  }

  /// Releases an unused or pending preload without starting another request.
  void clear() {
    final entry = _pending;
    _pending = null;
    if (entry == null) return;
    if (entry.valid && entry.ready.isCompleted && !entry.claimed) {
      AdMobKit.reportEvent(
        AdEvent(
          format: AdFormat.banner,
          type: AdEventType.invalidated,
          timestamp: DateTime.now(),
          adUnitId: entry.unit,
        ),
      );
    }
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

class _PendingBanner {
  _PendingBanner(this.size, this.unit, this.testMode);
  final AdSize size;
  final String unit;
  final bool testMode;
  final String? configuredUnit = AdMobKit.config.bannerId;
  Object? owner;
  final ready = Completer<BannerAd?>();
  BannerAd? ad;
  AdSize? actualSize;
  Timer? timer;
  bool valid = true;
  bool loaded = false;
  bool loadCallbackActive = false;
  bool claimed = false;
  bool matches(AdSize target, String targetUnit) =>
      valid &&
      unit == targetUnit &&
      testMode == AdMobKit.config.testMode &&
      size.runtimeType == target.runtimeType &&
      size == target &&
      (size is! InlineAdaptiveSize ||
          (target is InlineAdaptiveSize &&
              (size as InlineAdaptiveSize).maxHeight == target.maxHeight &&
              (size as InlineAdaptiveSize).orientation == target.orientation));
}
