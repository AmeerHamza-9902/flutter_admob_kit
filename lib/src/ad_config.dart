import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Platform-specific AdMob Ad Unit ID configuration.
class AdPlatformConfig {
  const AdPlatformConfig({
    this.interstitial,
    this.rewarded,
    this.appOpen,
    this.banner,
    this.native,
  });

  final String? interstitial;
  final String? rewarded;
  final String? appOpen;
  final String? banner;
  final String? native;

  AdPlatformConfig copyWith({
    String? interstitial,
    String? rewarded,
    String? appOpen,
    String? banner,
    String? native,
  }) {
    return AdPlatformConfig(
      interstitial: interstitial ?? this.interstitial,
      rewarded: rewarded ?? this.rewarded,
      appOpen: appOpen ?? this.appOpen,
      banner: banner ?? this.banner,
      native: native ?? this.native,
    );
  }
}

/// Central configuration for flutter_admob_kit.
class AdMobConfig {
  const AdMobConfig({
    this.android,
    this.ios,
    this.enableUmpConsent = false,
    this.interstitialCooldown = const Duration(seconds: 30),
    this.interstitialExpiry = const Duration(hours: 1),
    this.appOpenCooldown = const Duration(seconds: 10),
    this.appOpenExpiry = const Duration(hours: 4),
    this.rewardedExpiry = const Duration(hours: 1),
    this.autoResumeAppOpen = true,
    this.isEntitled = false,
  });

  /// Android ad unit configuration.
  final AdPlatformConfig? android;

  /// iOS ad unit configuration.
  final AdPlatformConfig? ios;

  /// Whether to automatically check and request Google UMP consent on initialization.
  final bool enableUmpConsent;

  /// Minimum duration between consecutive interstitial impressions.
  final Duration interstitialCooldown;

  /// Maximum lifespan before a cached interstitial ad is considered stale and evicted.
  final Duration interstitialExpiry;

  /// Minimum duration between consecutive App Open impressions on resume.
  final Duration appOpenCooldown;

  /// Maximum lifespan before a cached App Open ad is considered stale (Google advises 4 hours).
  final Duration appOpenExpiry;

  /// Maximum lifespan before a cached Rewarded ad is considered stale.
  final Duration rewardedExpiry;

  /// Automatically presents App Open ads when returning from background.
  final bool autoResumeAppOpen;

  /// When `true`, user is marked as premium/entitled and all ads are suppressed.
  final bool isEntitled;

  /// Resolves the active Interstitial Ad Unit ID.
  String? get interstitialId => _activePlatformConfig?.interstitial;

  /// Resolves the active Rewarded Ad Unit ID.
  String? get rewardedId => _activePlatformConfig?.rewarded;

  /// Resolves the active App Open Ad Unit ID.
  String? get appOpenId => _activePlatformConfig?.appOpen;

  /// Resolves the active Banner Ad Unit ID.
  String? get bannerId => _activePlatformConfig?.banner;

  /// Resolves the active Native Ad Unit ID.
  String? get nativeId => _activePlatformConfig?.native;

  bool get _isIos {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  AdPlatformConfig? get _activePlatformConfig => _isIos ? ios : android;

  AdMobConfig copyWith({
    AdPlatformConfig? android,
    AdPlatformConfig? ios,
    bool? enableUmpConsent,
    Duration? interstitialCooldown,
    Duration? interstitialExpiry,
    Duration? appOpenCooldown,
    Duration? appOpenExpiry,
    Duration? rewardedExpiry,
    bool? autoResumeAppOpen,
    bool? isEntitled,
  }) {
    return AdMobConfig(
      android: android ?? this.android,
      ios: ios ?? this.ios,
      enableUmpConsent: enableUmpConsent ?? this.enableUmpConsent,
      interstitialCooldown: interstitialCooldown ?? this.interstitialCooldown,
      interstitialExpiry: interstitialExpiry ?? this.interstitialExpiry,
      appOpenCooldown: appOpenCooldown ?? this.appOpenCooldown,
      appOpenExpiry: appOpenExpiry ?? this.appOpenExpiry,
      rewardedExpiry: rewardedExpiry ?? this.rewardedExpiry,
      autoResumeAppOpen: autoResumeAppOpen ?? this.autoResumeAppOpen,
      isEntitled: isEntitled ?? this.isEntitled,
    );
  }
}
