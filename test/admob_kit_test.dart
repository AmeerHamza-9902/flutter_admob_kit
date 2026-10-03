import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_mobile_ads'),
      (MethodCall methodCall) async {
        return null;
      },
    );
    AdMobKit.resetForTesting();
  });

  group('AdMobKit Initialization & Facade', () {
    test('initializes cleanly and idempotently', () async {
      expect(AdMobKit.isInitialized, isFalse);

      await AdMobKit.initialize(
        config: const AdMobConfig(testMode: true),
        autoPreload: false,
      );

      expect(AdMobKit.isInitialized, isTrue);
      expect(AdMobKit.config.testMode, isTrue);

      // Calling initialize a second time must NOT throw and must not duplicate state
      await AdMobKit.initialize(
        config: const AdMobConfig(testMode: false),
        autoPreload: false,
      );

      // Still initialized and previous state preserved
      expect(AdMobKit.isInitialized, isTrue);
    });

    test('show(false) returns false without presenting or loading', () async {
      await AdMobKit.initialize(
        config: const AdMobConfig(testMode: true),
        autoPreload: false,
      );

      final interstitialResult = await AdMobKit.interstitial.show(false);
      expect(interstitialResult, isFalse);

      final rewardedResult = await AdMobKit.rewarded.show(false);
      expect(rewardedResult, isFalse);

      final appOpenResult = await AdMobKit.appOpen.show(false);
      expect(appOpenResult, isFalse);
    });

    test('global entitlement gate suppresses all ad presentations', () async {
      await AdMobKit.initialize(
        config: const AdMobConfig(testMode: true, isEntitled: false),
        autoPreload: false,
      );

      expect(AdMobKit.isEntitled, isFalse);

      AdMobKit.setEntitled(true);
      expect(AdMobKit.isEntitled, isTrue);

      // When entitled, show(true) immediately returns false
      expect(await AdMobKit.interstitial.show(true), isFalse);
      expect(await AdMobKit.rewarded.show(true), isFalse);
      expect(await AdMobKit.appOpen.show(true), isFalse);
    });
  });
}
