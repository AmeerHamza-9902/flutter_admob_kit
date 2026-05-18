// lib/config/ads_config.dart

class InterstitialSlot {
  final String adUnit;
  final int clickThreshold;
  final bool show;

  const InterstitialSlot({
    required this.adUnit,
    this.clickThreshold = 3,
    this.show = true,
  });

  factory InterstitialSlot.fromJson(Map<String, dynamic> json) =>
      InterstitialSlot(
        adUnit: json['adUnit'] as String? ?? '',
        clickThreshold: json['click_threshold'] as int? ?? 3,
        show: json['show'] as bool? ?? true,
      );
}

class ClickInterstitialSlot {
  final String adUnitId;
  final bool isEnabled;
  final int clickThreshold;

  const ClickInterstitialSlot({
    required this.adUnitId,
    this.isEnabled = true,
    this.clickThreshold = 3,
  });

  factory ClickInterstitialSlot.fromJson(Map<String, dynamic> json) =>
      ClickInterstitialSlot(
        adUnitId: json['ad_unit_id'] as String? ?? '',
        isEnabled: json['is_enabled'] as bool? ?? true,
        clickThreshold: json['click_threshold'] as int? ?? 3,
      );
}

class AppOpenSlot {
  final String adUnit;
  final bool show;

  const AppOpenSlot({required this.adUnit, this.show = true});

  factory AppOpenSlot.fromJson(Map<String, dynamic> json) => AppOpenSlot(
        adUnit: json['adUnit'] as String? ?? '',
        show: json['show'] as bool? ?? true,
      );
}

class ScreenAdConfig {
  final String? nativeId;
  final bool nativeAds;
  final String? bannerId;
  final bool bannerAds;
  final String? interstitialId;
  final bool interstitialAds;

  const ScreenAdConfig({
    this.nativeId,
    this.nativeAds = false,
    this.bannerId,
    this.bannerAds = false,
    this.interstitialId,
    this.interstitialAds = false,
  });

  factory ScreenAdConfig.fromJson(Map<String, dynamic> json) => ScreenAdConfig(
        nativeId: json['native_id'] as String?,
        nativeAds: json['native_ads'] as bool? ?? false,
        bannerId: json['banner_id'] as String?,
        bannerAds: json['banner_ads'] as bool? ?? false,
        interstitialId: json['interstitial_id'] as String?,
        interstitialAds: json['interstitial_ads'] as bool? ?? false,
      );
}

class AdsConfig {
  final InterstitialSlot? interstitialBtmNav;
  final InterstitialSlot? proCloseInterstitial;
  final ClickInterstitialSlot? clickInterstitial;
  final InterstitialSlot? splashInterstitial;
  final AppOpenSlot? splashAppOpen;
  final AppOpenSlot? onResumeAppOpen;
  final Map<String, ScreenAdConfig> screens;

  const AdsConfig({
    this.interstitialBtmNav,
    this.proCloseInterstitial,
    this.clickInterstitial,
    this.splashInterstitial,
    this.splashAppOpen,
    this.onResumeAppOpen,
    this.screens = const {},
  });

  ScreenAdConfig screenConfig(String screenKey) =>
      screens[screenKey] ?? const ScreenAdConfig();

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    InterstitialSlot? interstitialSlot(String key) =>
        json.containsKey(key) ? InterstitialSlot.fromJson(json[key]) : null;

    AppOpenSlot? appOpenSlot(String key) =>
        json.containsKey(key) ? AppOpenSlot.fromJson(json[key]) : null;

    final screens = <String, ScreenAdConfig>{};
    if (json['Screens'] is Map) {
      (json['Screens'] as Map).forEach((key, value) {
        if (value is Map<String, dynamic>) {
          screens[key as String] = ScreenAdConfig.fromJson(value);
        }
      });
    }

    return AdsConfig(
      interstitialBtmNav: interstitialSlot('Interstitial_btm_nav'),
      proCloseInterstitial: interstitialSlot('ProCloseInterstitial'),
      clickInterstitial: json.containsKey('click_interstitial')
          ? ClickInterstitialSlot.fromJson(json['click_interstitial'])
          : null,
      splashInterstitial: interstitialSlot('SplashInterstitial'),
      splashAppOpen: appOpenSlot('SplashAppOpen'),
      onResumeAppOpen: appOpenSlot('OnResumeAppOpen'),
      screens: screens,
    );
  }
}
