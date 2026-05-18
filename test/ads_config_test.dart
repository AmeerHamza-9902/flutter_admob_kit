import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'dart:convert';

void main() {
  group('AdsConfig', () {
    late AdsConfig config;

    setUp(() {
      const jsonStr = '''
      {
        "Interstitial_btm_nav": {
          "adUnit": "ca-app-pub-3940256099942544/1033173712",
          "click_threshold": 3,
          "show": true
        },
        "ProCloseInterstitial": {
          "adUnit": "ca-app-pub-3940256099942544/1033173712",
          "show": true
        },
        "click_interstitial": {
          "ad_unit_id": "ca-app-pub-3940256099942544/1033173712",
          "is_enabled": true,
          "click_threshold": 3
        },
        "SplashInterstitial": {
          "adUnit": "ca-app-pub-3940256099942544/1033173712",
          "show": false
        },
        "SplashAppOpen": {
          "adUnit": "ca-app-pub-3940256099942544/9257395921",
          "show": true
        },
        "OnResumeAppOpen": {
          "adUnit": "ca-app-pub-3940256099942544/9257395921",
          "show": true
        },
        "Screens": {
          "home_screen": {
            "native_id": "ca-app-pub-3940256099942544/2247696110",
            "native_ads": true,
            "banner_id": "ca-app-pub-3940256099942544/6300978111",
            "banner_ads": true
          },
          "setting_screen": {
            "native_id": "ca-app-pub-3940256099942544/2247696110",
            "native_ads": true,
            "banner_id": "ca-app-pub-3940256099942544/6300978111",
            "banner_ads": false
          }
        }
      }
      ''';
      config = AdsConfig.fromJson(json.decode(jsonStr));
    });

    test('parses interstitialBtmNav correctly', () {
      expect(config.interstitialBtmNav, isNotNull);
      expect(config.interstitialBtmNav!.clickThreshold, 3);
      expect(config.interstitialBtmNav!.show, true);
    });

    test('parses click_interstitial with correct field names', () {
      expect(config.clickInterstitial, isNotNull);
      expect(config.clickInterstitial!.adUnitId,
          'ca-app-pub-3940256099942544/1033173712');
      expect(config.clickInterstitial!.isEnabled, true);
    });

    test('show: false is respected', () {
      expect(config.splashInterstitial!.show, false);
    });

    test('parses screen configs correctly', () {
      final home = config.screenConfig('home_screen');
      expect(home.bannerAds, true);
      expect(home.nativeAds, true);
      expect(home.bannerId, 'ca-app-pub-3940256099942544/6300978111');
    });

    test('setting_screen banner_ads is false', () {
      final setting = config.screenConfig('setting_screen');
      expect(setting.bannerAds, false);
      expect(setting.nativeAds, true);
    });

    test('unknown screen returns empty ScreenAdConfig', () {
      final unknown = config.screenConfig('unknown_screen');
      expect(unknown.bannerAds, false);
      expect(unknown.nativeAds, false);
      expect(unknown.bannerId, isNull);
    });

    test('parses AppOpen slots', () {
      expect(config.splashAppOpen, isNotNull);
      expect(config.splashAppOpen!.show, true);
      expect(config.onResumeAppOpen, isNotNull);
    });
  });
}
