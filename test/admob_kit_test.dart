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
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'ca-app-pub-test/111'),
        ),
        autoPreload: false,
      );

      expect(AdMobKit.isInitialized, isTrue);
      expect(AdMobKit.config.interstitialId, 'ca-app-pub-test/111');

      // Calling initialize a second time must NOT throw and must not duplicate state
      await AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'ca-app-pub-test/222'),
        ),
        autoPreload: false,
      );

      // Still initialized and previous state preserved
      expect(AdMobKit.isInitialized, isTrue);
    });

    test(
        'preloads Rewarded alongside Interstitial and AppOpen on initialization',
        () async {
      await AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(
            interstitial: 'ca-app-pub-test/111',
            rewarded: 'ca-app-pub-test/222',
            appOpen: 'ca-app-pub-test/333',
          ),
        ),
        autoPreload: true,
      );

      expect(AdMobKit.isInitialized, isTrue);
      expect(AdMobKit.rewarded.state, isNot(AdState.disposed));
    });

    test('show(false) returns false without presenting or loading', () async {
      await AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(
            interstitial: 'ca-app-pub-test/111',
            rewarded: 'ca-app-pub-test/222',
            appOpen: 'ca-app-pub-test/333',
          ),
        ),
        autoPreload: false,
      );

      final interstitialResult = await AdMobKit.interstitial.show(false);
      expect(interstitialResult, isFalse);

      final rewardedResult = await AdMobKit.rewarded.show(false);
      expect(rewardedResult, isFalse);

      final appOpenResult = await AdMobKit.appOpen.show(false);
      expect(appOpenResult, isFalse);
    });

    test('concurrent initialize calls share single future and do not duplicate',
        () async {
      expect(AdMobKit.isInitialized, isFalse);

      final f1 = AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'ca-app-pub-test/111'),
        ),
        autoPreload: false,
      );
      final f2 = AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'ca-app-pub-test/111'),
        ),
        autoPreload: false,
      );

      // Both should be the same underlying future
      expect(identical(f1, f2), isTrue);

      await Future.wait([f1, f2]);
      expect(AdMobKit.isInitialized, isTrue);
    });

    test('updateConfig invalidates ad managers when ad unit IDs change',
        () async {
      await AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'ca-app-pub-old/111'),
        ),
        autoPreload: false,
      );

      expect(AdMobKit.config.interstitialId, 'ca-app-pub-old/111');

      AdMobKit.updateConfig(
        const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'ca-app-pub-new/222'),
        ),
      );

      expect(AdMobKit.config.interstitialId, 'ca-app-pub-new/222');
    });

    test('initialization failure allows safe retry and does not deadlock',
        () async {
      expect(AdMobKit.isInitialized, isFalse);

      AdMobKit.testHookBeforeInit = () {
        throw Exception('Simulated network/SDK init error');
      };

      // First attempt fails
      await expectLater(
        AdMobKit.initialize(
          config: const AdMobConfig(
            android: AdPlatformConfig(interstitial: 'ca-app-pub-test/111'),
          ),
          autoPreload: false,
        ),
        throwsA(isA<Exception>()),
      );

      expect(AdMobKit.isInitialized, isFalse);

      // Clear the failure hook
      AdMobKit.testHookBeforeInit = null;

      // Retry must succeed cleanly
      await AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'ca-app-pub-test/111'),
        ),
        autoPreload: false,
      );

      expect(AdMobKit.isInitialized, isTrue);
    });

    test('updateConfig with testMode true invalidates and switches to test IDs',
        () async {
      await AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'prod/111'),
        ),
        autoPreload: false,
      );

      expect(AdMobKit.config.interstitialId, 'prod/111');
      expect(AdMobKit.config.testMode, isFalse);

      AdMobKit.updateConfig(
        AdMobKit.config.copyWith(testMode: true),
      );

      expect(AdMobKit.config.testMode, isTrue);
      expect(
        AdMobKit.config.interstitialId,
        'ca-app-pub-3940256099942544/1033173712',
      );
    });

    test('setEntitled(true) suppresses preloading and clears cached state',
        () async {
      await AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'ca-app-pub-test/111'),
        ),
        autoPreload: false,
      );

      AdMobKit.setEntitled(true);
      expect(AdMobKit.isEntitled, isTrue);

      // Subsequent show calls immediately return false
      expect(await AdMobKit.interstitial.show(true), isFalse);

      // Re-enabling entitlement
      AdMobKit.setEntitled(false);
      expect(AdMobKit.isEntitled, isFalse);
    });

    test('NativeAdWidget provides only small and medium constructors', () {
      const smallWidget = NativeAdWidget.small();
      expect(smallWidget.template, NativeTemplate.small);
      expect(smallWidget.height, 90.0);

      const mediumWidget = NativeAdWidget.medium();
      expect(mediumWidget.template, NativeTemplate.medium);
      expect(mediumWidget.height, 320.0);
    });
  });
}
