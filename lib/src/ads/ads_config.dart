import 'dart:convert';

import 'package:flutter/services.dart';

/// Runtime ad configuration parsed from JSON.
///
/// Supports both `snake_case` and `camelCase` JSON keys for backward
/// compatibility. Prefer `snake_case` in new configurations.
class AdsConfig {
  const AdsConfig({
    this.interstitialBtmNav,
    this.proCloseInterstitial,
    this.clickInterstitial,
    this.splashInterstitial,
    this.splashAppOpen,
    this.onResumeAppOpen,
    this.rewarded,
    this.rewardedInterstitial,
    this.screens = const <String, ScreenAdConfig>{},
    this.isEntitled = false,
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    return AdsConfig(
      interstitialBtmNav: AdSlotConfig.fromJsonOrNull(
        json['Interstitial_btm_nav'] ?? json['interstitial_btm_nav'],
      ),
      proCloseInterstitial: AdSlotConfig.fromJsonOrNull(
        json['ProCloseInterstitial'] ?? json['pro_close_interstitial'],
      ),
      clickInterstitial: AdSlotConfig.fromJsonOrNull(
        json['click_interstitial'] ?? json['ClickInterstitial'],
      ),
      splashInterstitial: AdSlotConfig.fromJsonOrNull(
        json['SplashInterstitial'] ?? json['splash_interstitial'],
      ),
      splashAppOpen: AdSlotConfig.fromJsonOrNull(
        json['SplashAppOpen'] ?? json['splash_app_open'],
      ),
      onResumeAppOpen: AdSlotConfig.fromJsonOrNull(
        json['OnResumeAppOpen'] ?? json['on_resume_app_open'],
      ),
      rewarded: AdSlotConfig.fromJsonOrNull(
        json['Rewarded'] ?? json['rewarded'],
      ),
      rewardedInterstitial: AdSlotConfig.fromJsonOrNull(
        json['RewardedInterstitial'] ?? json['rewarded_interstitial'],
      ),
      screens: _parseScreens(json['Screens'] ?? json['screens']),
      isEntitled: _bool(json['is_entitled']),
    );
  }

  /// Loads configuration from a Flutter asset JSON file.
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
  final AdSlotConfig? rewarded;
  final AdSlotConfig? rewardedInterstitial;
  final Map<String, ScreenAdConfig> screens;

  /// Whether the user is entitled / premium (all ads suppressed).
  final bool isEntitled;

  /// Returns screen-specific banner/native configuration for [screenKey].
  ScreenAdConfig screenConfig(String screenKey) {
    return screens[screenKey] ?? const ScreenAdConfig();
  }

  /// Returns a copy of this config with the given fields replaced.
  AdsConfig copyWith({
    AdSlotConfig? interstitialBtmNav,
    AdSlotConfig? proCloseInterstitial,
    AdSlotConfig? clickInterstitial,
    AdSlotConfig? splashInterstitial,
    AdSlotConfig? splashAppOpen,
    AdSlotConfig? onResumeAppOpen,
    AdSlotConfig? rewarded,
    AdSlotConfig? rewardedInterstitial,
    Map<String, ScreenAdConfig>? screens,
    bool? isEntitled,
  }) {
    return AdsConfig(
      interstitialBtmNav: interstitialBtmNav ?? this.interstitialBtmNav,
      proCloseInterstitial: proCloseInterstitial ?? this.proCloseInterstitial,
      clickInterstitial: clickInterstitial ?? this.clickInterstitial,
      splashInterstitial: splashInterstitial ?? this.splashInterstitial,
      splashAppOpen: splashAppOpen ?? this.splashAppOpen,
      onResumeAppOpen: onResumeAppOpen ?? this.onResumeAppOpen,
      rewarded: rewarded ?? this.rewarded,
      rewardedInterstitial: rewardedInterstitial ?? this.rewardedInterstitial,
      screens: screens ?? this.screens,
      isEntitled: isEntitled ?? this.isEntitled,
    );
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

/// Shared configuration for interstitial/app-open/rewarded ad slots.
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
      adUnitId: _string(value['adUnit']) ??
          _string(value['ad_unit_id']) ??
          _string(value['ad_unit']),
      show: _bool(value['show'], fallback: false),
      isEnabled: _bool(value['is_enabled'], fallback: _bool(value['show'])),
      clickThreshold: _int(value['click_threshold'], fallback: 3),
    );
  }

  static AdSlotConfig? fromJsonOrNull(Object? value) {
    if (value == null) return null;
    return AdSlotConfig.fromJson(value);
  }

  /// The AdMob ad unit ID.
  final String? adUnitId;

  /// Whether this ad slot is active.
  final bool show;

  /// Alternative enable flag (maps from `is_enabled` JSON key).
  final bool isEnabled;

  /// Number of clicks before the ad triggers (for click-counter placements).
  final int clickThreshold;

  /// Returns `true` if this slot is configured with a valid ad unit and is active.
  bool get isActive => adUnitId != null && (show || isEnabled);
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

  /// The AdMob native ad unit ID.
  final String? nativeId;

  /// Whether native ads are enabled for this screen.
  final bool nativeAds;

  /// The AdMob banner ad unit ID.
  final String? bannerId;

  /// Whether banner ads are enabled for this screen.
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
