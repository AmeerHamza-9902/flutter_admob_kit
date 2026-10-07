import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final channel = MethodChannel(
    'plugins.flutter.io/google_mobile_ads',
    StandardMethodCodec(AdMessageCodec()),
  );
  const ump = MethodChannel('plugins.flutter.io/google_mobile_ads/ump');

  setUp(() async {
    AdMobKit.resetForTesting();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'MobileAds#initialize') {
            return InitializationStatus({});
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ump, (call) async {
          if (call.method == 'ConsentInformation#canRequestAds') return true;
          return null;
        });
    await ConsentManager.instance.reset();
  });
  tearDown(AdMobKit.resetForTesting);

  List<MethodCall> loads(String format) =>
      calls.where((call) => call.method == 'load${format}Ad').toList();

  Future<void> adEvent(int id, String eventName, {LoadAdError? error}) async {
    final done = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            MethodCall('onAdEvent', {
              'adId': id,
              'eventName': eventName,
              'loadAdError': ?error,
            }),
          ),
          (_) => done.complete(),
        );
    await done.future;
  }

  test(
    'named interstitials keep independent cached units and report placement IDs',
    () async {
      AdMobKit.registerFullscreenPlacements(const [
        FullscreenPlacement.interstitial(
          id: 'settings',
          androidId: 'unit-settings',
        ),
        FullscreenPlacement.interstitial(
          id: 'history',
          androidId: 'unit-history',
        ),
      ]);
      final events = <AdEvent>[];
      AdMobKit.addEventListener(events.add);
      await AdMobKit.initialize(
        config: const AdMobConfig(enableUmpConsent: false),
      );
      await Future<void>.delayed(Duration.zero);
      final initial = loads('Interstitial');
      expect(
        initial.map((call) => call.arguments['adUnitId']),
        containsAll(['unit-settings', 'unit-history']),
      );
      expect(initial, hasLength(2));
      final settings = AdMobKit.interstitialFor('settings');
      final history = AdMobKit.interstitialFor('history');
      expect(identical(settings, history), isFalse);
      expect(identical(settings, AdMobKit.interstitial), isFalse);

      final settingsId =
          initial
                  .singleWhere(
                    (call) => call.arguments['adUnitId'] == 'unit-settings',
                  )
                  .arguments['adId']
              as int;
      await adEvent(settingsId, 'onAdLoaded');
      expect(settings.isReady, isTrue);
      expect(history.isReady, isFalse);
      expect(
        events
            .where((event) => event.type == AdEventType.loaded)
            .single
            .placementId,
        'settings',
      );

      AdMobKit.registerFullscreenPlacements(const [
        FullscreenPlacement.interstitial(
          id: 'settings',
          androidId: 'unit-settings',
        ),
      ]);
      expect(loads('Interstitial'), hasLength(2));
      expect(identical(settings, AdMobKit.interstitialFor('settings')), isTrue);
      AdMobKit.setEntitled(true);
      expect(settings.isReady, isFalse);
      expect(await history.show(true), isFalse);
      AdMobKit.unregisterFullscreenPlacement(AdFormat.interstitial, 'settings');
      expect(settings.state, AdState.disposed);
      expect(() => AdMobKit.interstitialFor('settings'), throwsStateError);
      expect(history.state, isNot(AdState.disposed));
    },
  );

  test('changing one placement waits for its old in-flight request', () async {
    AdMobKit.registerFullscreenPlacements(const [
      FullscreenPlacement.interstitial(id: 'settings', androidId: 'old-unit'),
      FullscreenPlacement.interstitial(
        id: 'history',
        androidId: 'history-unit',
      ),
    ]);
    await AdMobKit.initialize(
      config: const AdMobConfig(enableUmpConsent: false),
    );
    await Future<void>.delayed(Duration.zero);
    expect(loads('Interstitial'), hasLength(2));
    final oldId =
        loads('Interstitial')
                .singleWhere((call) => call.arguments['adUnitId'] == 'old-unit')
                .arguments['adId']
            as int;

    AdMobKit.registerFullscreenPlacements(const [
      FullscreenPlacement.interstitial(id: 'settings', androidId: 'new-unit'),
    ]);
    expect(loads('Interstitial'), hasLength(2));
    await adEvent(
      oldId,
      'onAdFailedToLoad',
      error: LoadAdError(2, 'test', 'old request finished', null),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      loads('Interstitial').map((call) => call.arguments['adUnitId']),
      contains('new-unit'),
    );
    expect(
      loads(
        'Interstitial',
      ).where((call) => call.arguments['adUnitId'] == 'history-unit'),
      hasLength(1),
    );
  });

  test(
    'rewarded and App Open placements use their own format managers',
    () async {
      AdMobKit.registerFullscreenPlacements(const [
        FullscreenPlacement.rewarded(id: 'bonus', androidId: 'reward-unit'),
        FullscreenPlacement.appOpen(id: 'manual', androidId: 'open-unit'),
      ]);
      await AdMobKit.initialize(
        config: const AdMobConfig(enableUmpConsent: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(loads('Rewarded').single.arguments['adUnitId'], 'reward-unit');
      expect(loads('AppOpen').single.arguments['adUnitId'], 'open-unit');
      expect(AdMobKit.rewardedFor('bonus'), isA<RewardedManager>());
      expect(AdMobKit.appOpenFor('manual'), isA<AppOpenManager>());
      expect(() => AdMobKit.interstitialFor('bonus'), throwsStateError);
    },
  );

  test('placements registered after initialization preload once', () async {
    await AdMobKit.initialize(
      config: const AdMobConfig(enableUmpConsent: false),
    );
    AdMobKit.registerFullscreenPlacements(const [
      FullscreenPlacement.interstitial(id: 'late', androidId: 'late-unit'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(loads('Interstitial').single.arguments['adUnitId'], 'late-unit');
    AdMobKit.registerFullscreenPlacements(const [
      FullscreenPlacement.interstitial(id: 'late', androidId: 'late-unit'),
    ]);
    expect(loads('Interstitial'), hasLength(1));
  });

  test('test mode substitutes official IDs for named placements', () async {
    AdMobKit.registerFullscreenPlacements(const [
      FullscreenPlacement.interstitial(id: 'settings', androidId: 'real-unit'),
    ]);
    await AdMobKit.initialize(
      config: const AdMobConfig(enableUmpConsent: false, testMode: true),
    );
    await Future<void>.delayed(Duration.zero);
    expect(loads('Interstitial'), hasLength(1));
    await adEvent(
      loads('AppOpen').single.arguments['adId'] as int,
      'onAdLoaded',
    );
    await adEvent(
      loads('Interstitial').single.arguments['adId'] as int,
      'onAdLoaded',
    );
    await Future<void>.delayed(Duration.zero);
    expect(loads('Interstitial'), hasLength(2));
    expect(
      loads('Interstitial').map((call) => call.arguments['adUnitId']),
      everyElement('ca-app-pub-3940256099942544/1033173712'),
    );
  });

  test('placement IDs and ad units are validated before mutation', () {
    expect(
      () => AdMobKit.registerFullscreenPlacements(const [
        FullscreenPlacement.interstitial(id: 'valid', androidId: 'unit'),
        FullscreenPlacement.rewarded(id: 'default', androidId: 'unit'),
      ]),
      throwsArgumentError,
    );
    expect(
      () => AdMobKit.registerFullscreenPlacements(const [
        FullscreenPlacement.interstitial(id: 'valid', androidId: 'unit'),
      ]),
      returnsNormally,
    );
    expect(
      () => AdMobKit.registerFullscreenPlacements(const [
        FullscreenPlacement.appOpen(id: 'empty'),
      ]),
      throwsArgumentError,
    );
    expect(
      () => AdMobKit.registerFullscreenPlacements(const [
        FullscreenPlacement.interstitial(id: 'same', androidId: 'one'),
        FullscreenPlacement.interstitial(id: 'same', androidId: 'two'),
      ]),
      throwsArgumentError,
    );
  });
}
