import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'banner/banner_preload_controller.dart';
import 'banner/banner_size_key.dart';
import 'native/native_preload_controller.dart';
import 'native/native_templates.dart';

/// Library-owned inline ad caches. This implementation is intentionally not
/// exported from the package API.
class InlinePreload {
  InlinePreload._();

  static bool enabled = true;
  static final Map<
    (NativeTemplate, NativeAdStyle, String),
    NativePreloadController
  >
  _nativeCache = {};
  static final Map<(String, String), BannerPreloadController> _bannerCache = {};

  static NativePreloadController nativeCache(
    NativeTemplate template,
    NativeAdStyle style,
    String unit,
  ) {
    final key = (template, style, unit);
    final controller = _nativeCache.putIfAbsent(key, () {
      late final NativePreloadController created;
      created = NativePreloadController(
        onIdle: () {
          if (identical(_nativeCache[key], created)) {
            _nativeCache.remove(key);
            created.dispose();
          }
        },
      );
      return created;
    });
    unawaited(
      controller.preload(template: template, style: style, adUnitId: unit),
    );
    return controller;
  }

  static BannerPreloadController bannerCache(AdSize size, String unit) {
    final shape = bannerSizeKey(size);
    final key = (shape, unit);
    final controller = _bannerCache.putIfAbsent(key, () {
      late final BannerPreloadController created;
      created = BannerPreloadController(
        onIdle: () {
          if (identical(_bannerCache[key], created)) {
            _bannerCache.remove(key);
            created.dispose();
          }
        },
      );
      return created;
    });
    unawaited(controller.preload(size: size, adUnitId: unit));
    return controller;
  }

  static void replenishNative(
    NativeTemplate template,
    NativeAdStyle style,
    String unit, {
    required bool canRequestAds,
  }) {
    if (canRequestAds) nativeCache(template, style, unit);
  }

  static void replenishBanner(
    AdSize size,
    String unit, {
    required bool canRequestAds,
  }) {
    if (canRequestAds) bannerCache(size, unit);
  }

  static void warm(AdMobConfig config, {required bool canRequestAds}) {
    if (!canRequestAds || !enabled) return;
    final nativeUnit = config.nativeId;
    if (nativeUnit != null && nativeUnit.isNotEmpty) {
      for (final template in [
        NativeTemplate.bigNative,
        NativeTemplate.mediumNative,
      ]) {
        nativeCache(template, const NativeAdStyle(), nativeUnit);
      }
    }
    final bannerUnit = config.bannerId;
    if (bannerUnit != null && bannerUnit.isNotEmpty) {
      bannerCache(AdSize.largeBanner, bannerUnit);
    }
  }

  static void clear() {
    final native = _nativeCache.values.toList();
    final banner = _bannerCache.values.toList();
    _nativeCache.clear();
    _bannerCache.clear();
    for (final controller in native) {
      controller.dispose();
    }
    for (final controller in banner) {
      controller.dispose();
    }
  }
}
