import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Official Google AdMob sample test ad unit IDs.
class AdMobTestIds {
  const AdMobTestIds._();

  // Android official test ad units
  static const String androidBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String androidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String androidRewarded =
      'ca-app-pub-3940256099942544/5224354917';
  static const String androidAppOpen =
      'ca-app-pub-3940256099942544/9257395921';
  static const String androidNative =
      'ca-app-pub-3940256099942544/2247696110';

  // iOS official test ad units
  static const String iosBanner =
      'ca-app-pub-3940256099942544/2934735716';
  static const String iosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const String iosRewarded =
      'ca-app-pub-3940256099942544/1712485313';
  static const String iosAppOpen =
      'ca-app-pub-3940256099942544/5575463023';
  static const String iosNative =
      'ca-app-pub-3940256099942544/3986624511';
}

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
    this.testMode = false,
    this.enableUmpConsent = false,
    this.interstitialCooldown = const Duration(seconds: 30),
    this.appOpenCooldown = const Duration(seconds: 10),
    this.autoResumeAppOpen = true,
    this.isEntitled = false,
  });

  /// Android ad unit configuration.
  final AdPlatformConfig? android;

  /// iOS ad unit configuration.
  final AdPlatformConfig? ios;

  /// When `true`, Google's official test ad unit IDs will always be used.
  final bool testMode;

  /// Whether to automatically check and request Google UMP consent on initialization.
  final bool enableUmpConsent;

  /// Minimum duration between consecutive interstitial impressions.
  final Duration interstitialCooldown;

  /// Minimum duration between consecutive App Open impressions on resume.
  final Duration appOpenCooldown;

  /// Automatically presents App Open ads when returning from background.
  final bool autoResumeAppOpen;

  /// When `true`, user is marked as premium/entitled and all ads are suppressed.
  final bool isEntitled;

  /// Resolves the active Interstitial Ad Unit ID.
  String? get interstitialId {
    if (testMode) {
      return _isIos
          ? AdMobTestIds.iosInterstitial
          : AdMobTestIds.androidInterstitial;
    }
    return _activePlatformConfig?.interstitial;
  }

  /// Resolves the active Rewarded Ad Unit ID.
  String? get rewardedId {
    if (testMode) {
      return _isIos
          ? AdMobTestIds.iosRewarded
          : AdMobTestIds.androidRewarded;
    }
    return _activePlatformConfig?.rewarded;
  }

  /// Resolves the active App Open Ad Unit ID.
  String? get appOpenId {
    if (testMode) {
      return _isIos
          ? AdMobTestIds.iosAppOpen
          : AdMobTestIds.androidAppOpen;
    }
    return _activePlatformConfig?.appOpen;
  }

  /// Resolves the active Banner Ad Unit ID.
  String? get bannerId {
    if (testMode) {
      return _isIos
          ? AdMobTestIds.iosBanner
          : AdMobTestIds.androidBanner;
    }
    return _activePlatformConfig?.banner;
  }

  /// Resolves the active Native Ad Unit ID.
  String? get nativeId {
    if (testMode) {
      return _isIos
          ? AdMobTestIds.iosNative
          : AdMobTestIds.androidNative;
    }
    return _activePlatformConfig?.native;
  }

  bool get _isIos {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  AdPlatformConfig? get _activePlatformConfig =>
      _isIos ? ios : android;

  AdMobConfig copyWith({
    AdPlatformConfig? android,
    AdPlatformConfig? ios,
    bool? testMode,
    bool? enableUmpConsent,
    Duration? interstitialCooldown,
    Duration? appOpenCooldown,
    bool? autoResumeAppOpen,
    bool? isEntitled,
  }) {
    return AdMobConfig(
      android: android ?? this.android,
      ios: ios ?? this.ios,
      testMode: testMode ?? this.testMode,
      enableUmpConsent: enableUmpConsent ?? this.enableUmpConsent,
      interstitialCooldown:
          interstitialCooldown ?? this.interstitialCooldown,
      appOpenCooldown: appOpenCooldown ?? this.appOpenCooldown,
      autoResumeAppOpen: autoResumeAppOpen ?? this.autoResumeAppOpen,
      isEntitled: isEntitled ?? this.isEntitled,
    );
  }
}
