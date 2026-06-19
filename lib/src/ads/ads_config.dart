import 'dart:convert';

import 'package:flutter/services.dart';

/// Runtime ad configuration parsed from JSON.
class AdsConfig {
  const AdsConfig({
    this.interstitialBtmNav,
    this.proCloseInterstitial,
    this.clickInterstitial,
    this.splashInterstitial,
    this.splashAppOpen,
    this.onResumeAppOpen,
    this.screens = const <String, ScreenAdConfig>{},
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    return AdsConfig(
      interstitialBtmNav: AdSlotConfig.fromJsonOrNull(
        json['Interstitial_btm_nav'],
      ),
      proCloseInterstitial: AdSlotConfig.fromJsonOrNull(
        json['ProCloseInterstitial'],
      ),
      clickInterstitial: AdSlotConfig.fromJsonOrNull(
        json['click_interstitial'],
      ),
      splashInterstitial: AdSlotConfig.fromJsonOrNull(
        json['SplashInterstitial'],
      ),
      splashAppOpen: AdSlotConfig.fromJsonOrNull(json['SplashAppOpen']),
      onResumeAppOpen: AdSlotConfig.fromJsonOrNull(json['OnResumeAppOpen']),
      screens: _parseScreens(json['Screens']),
    );
  }

  static Future<AdsConfig> fromAsset(String assetPath) async {
    final jsonText = await rootBundle.loadString(assetPath);
    final decoded = json.decode(jsonText) as Map<String, dynamic>;
    return AdsConfig.fromJson(decoded);
  }

  final AdSlotConfig? interstitialBtmNav;
  final AdSlotConfig? proCloseInterstitial;
  final AdSlotConfig? clickInterstitial;
  final AdSlotConfig? splashInterstitial;
  final AdSlotConfig? splashAppOpen;
  final AdSlotConfig? onResumeAppOpen;
  final Map<String, ScreenAdConfig> screens;

  ScreenAdConfig screenConfig(String screenKey) {
    return screens[screenKey] ?? const ScreenAdConfig();
  }

  static Map<String, ScreenAdConfig> _parseScreens(Object? value) {
    if (value is! Map) return const <String, ScreenAdConfig>{};
    return value.map(
      (key, screenJson) => MapEntry(
        key.toString(),
        ScreenAdConfig.fromJson(screenJson),
      ),
    );
  }
}

/// Shared configuration for interstitial/app-open ad slots.
class AdSlotConfig {
  const AdSlotConfig({
    this.adUnitId,
    this.show = false,
    this.isEnabled = false,
    this.clickThreshold = 3,
  });

  factory AdSlotConfig.fromJson(Object? value) {
    if (value is! Map) return const AdSlotConfig();
    return AdSlotConfig(
      adUnitId: _string(value['adUnit']) ?? _string(value['ad_unit_id']),
      show: _bool(value['show'], fallback: false),
      isEnabled: _bool(value['is_enabled'], fallback: _bool(value['show'])),
      clickThreshold: _int(value['click_threshold'], fallback: 3),
    );
  }

  static AdSlotConfig? fromJsonOrNull(Object? value) {
    if (value == null) return null;
    return AdSlotConfig.fromJson(value);
  }

  final String? adUnitId;
  final bool show;
  final bool isEnabled;
  final int clickThreshold;
}

/// Banner/native configuration for one screen.
class ScreenAdConfig {
  const ScreenAdConfig({
    this.nativeId,
    this.nativeAds = false,
    this.bannerId,
    this.bannerAds = false,
  });

  factory ScreenAdConfig.fromJson(Object? value) {
    if (value is! Map) return const ScreenAdConfig();
    return ScreenAdConfig(
      nativeId: _string(value['native_id']),
      nativeAds: _bool(value['native_ads']),
      bannerId: _string(value['banner_id']),
      bannerAds: _bool(value['banner_ads']),
    );
  }

  final String? nativeId;
  final bool nativeAds;
  final String? bannerId;
  final bool bannerAds;
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

bool _bool(Object? value, {bool fallback = false}) {
  return value is bool ? value : fallback;
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
