import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  var allowed = true;
  final channel = MethodChannel(
    'plugins.flutter.io/google_mobile_ads',
    StandardMethodCodec(AdMessageCodec()),
  );
  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_admob_kit/native_templates'),
          (_) async => null,
        );
    AdMobKit.resetForTesting();
    allowed = true;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'MobileAds#initialize') {
            return InitializationStatus({});
          }
          if (call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize') {
            return 50;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ump, (call) async {
          if (call.method == 'ConsentInformation#canRequestAds') return allowed;
          return null;
        });
    await ConsentManager.instance.reset();
  });
  tearDown(AdMobKit.resetForTesting);
  Future<void> initialize() => AdMobKit.initialize(
    config: const AdMobConfig(
      android: AdPlatformConfig(banner: 'banner-1', native: 'native-1'),
    ),
    autoPreload: false,
  );
  List<MethodCall> loads(String kind) =>
      calls.where((c) => c.method == 'load${kind}Ad').toList();
  Future<void> event(int id, String name, {LoadAdError? error}) async {
    final done = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            MethodCall('onAdEvent', {
              'adId': id,
              'eventName': name,
              'loadAdError': ?error,
            }),
          ),
          (_) => done.complete(),
        );
    await done.future;
  }

  testWidgets('Android medium uses bundled factory and developer style', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(
      const MaterialApp(
        home: NativeAdWidget.medium(
          style: NativeAdStyle(
            backgroundColor: Colors.black,
            primaryTextColor: Colors.white,
          ),
          showShimmer: false,
        ),
      ),
    );
    await tester.pump();
    final args = loads('Native').single.arguments as Map;
    expect(args['factoryId'], 'flutter_admob_kit/medium');
    expect(args['nativeTemplateStyle'], isNull);
    expect(args['customOptions']['backgroundColor'], Colors.black.toARGB32());
    expect(args['customOptions']['primaryTextColor'], Colors.white.toARGB32());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'medium height defaults to 280 and resizes without another request',
    (tester) async {
      await initialize();
      Future<void> show(double? height) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: NativeAdWidget.medium(height: height, showShimmer: true),
            ),
          ),
        );
        await tester.pump();
      }

      await show(null);
      expect(tester.getSize(find.byType(NativeAdWidget)).height, 280);
      expect(loads('Native'), hasLength(1));
      await show(450);
      expect(tester.getSize(find.byType(NativeAdWidget)).height, 450);
      expect(loads('Native'), hasLength(1));
      await show(280);
      expect(tester.getSize(find.byType(NativeAdWidget)).height, 280);
      expect(loads('Native'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('factory setup failure makes no native request', (tester) async {
    await initialize();
    var failed = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_admob_kit/native_templates'),
          (_) async {
            throw PlatformException(code: 'factory_conflict');
          },
        );
    await tester.pumpWidget(
      MaterialApp(
        home: NativeAdWidget.medium(
          onAdFailed: () => failed++,
          showShimmer: false,
        ),
      ),
    );
    await tester.pump();
    expect(loads('Native'), isEmpty);
    expect(failed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unmount during factory setup never starts a native load', (
    tester,
  ) async {
    await initialize();
    final setup = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_admob_kit/native_templates'),
          (_) => setup.future,
        );
    await tester.pumpWidget(
      const MaterialApp(home: NativeAdWidget.medium(showShimmer: false)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    setup.complete();
    await tester.pump();
    expect(loads('Native'), isEmpty);
  });

  testWidgets(
    'Android small keeps the official template with white background',
    (tester) async {
      await initialize();
      await tester.pumpWidget(
        const MaterialApp(home: NativeAdWidget.small(showShimmer: false)),
      );
      await tester.pump();
      final args = loads('Native').single.arguments as Map;
      expect(args['factoryId'], isNull);
      expect(
        (args['nativeTemplateStyle'] as NativeTemplateStyle)
            .mainBackgroundColor,
        Colors.white,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'adaptive banner uses container width and reloads once per size change',
    (tester) async {
      await initialize();
      Widget tree(double width) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: const BannerAdWidget.small(showShimmer: false),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree(320));
      await tester.pump();
      expect(loads('Banner').length, 1);
      await tester.pumpWidget(tree(320));
      await tester.pump();
      expect(loads('Banner').length, 1);
      await tester.pumpWidget(tree(400));
      await tester.pump();
      expect(loads('Banner').length, 2);
      final sizing = calls.where(
        (c) => c.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize',
      );
      expect(sizing.map((c) => c.arguments['width']), [320, 400]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('initialization failure is visible and retryable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'MobileAds#initialize') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        });
    await expectLater(initialize(), throwsA(isA<PlatformException>()));
    expect(AdMobKit.isInitialized, false);
    expect(AdMobKit.canRequestAds, false);
    expect(() => AdMobKit.interstitial, throwsStateError);
  });

  test(
    'initialize + entitlement + configuration change uses latest state',
    () async {
      final sdk = Completer<InitializationStatus>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'MobileAds#initialize') return sdk.future;
            return null;
          });
      final pending = initialize();
      await Future<void>.delayed(Duration.zero);
      AdMobKit.setEntitled(true);
      AdMobKit.updateConfig(
        AdMobKit.config.copyWith(
          android: const AdPlatformConfig(interstitial: 'latest'),
          isEntitled: true,
        ),
      );
      sdk.complete(InitializationStatus({}));
      await pending;
      expect(AdMobKit.isEntitled, true);
      expect(AdMobKit.config.interstitialId, 'latest');
      expect(calls.where((c) => c.method.startsWith('load')), isEmpty);
    },
  );

  test(
    'concurrent consent flow performs one update and blocks until form ends',
    () async {
      final form = Completer<void>();
      var updates = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ump, (call) async {
            if (call.method == 'ConsentInformation#requestConsentInfoUpdate') {
              updates++;
            }
            if (call.method ==
                'UserMessagingPlatform#loadAndShowConsentFormIfRequired') {
              await form.future;
            }
            if (call.method == 'ConsentInformation#canRequestAds') {
              return allowed;
            }
            return null;
          });
      final first = ConsentManager.instance.requestConsent();
      final second = ConsentManager.instance.requestConsent();
      expect(identical(first, second), true);
      expect(ConsentManager.instance.isConsentSafe, false);
      form.complete();
      expect(await first, true);
      expect(updates, 1);
    },
  );

  for (final kind in ['Banner', 'Native']) {
    Widget placement() => kind == 'Banner'
        ? const BannerAdWidget(showShimmer: false)
        : NativeAdWidget.small(
            showShimmer: false,
            style: NativeAdStyle(backgroundColor: Colors.white),
          );
    Widget tree() => MaterialApp(home: Scaffold(body: placement()));
    testWidgets(
      '$kind rebuild, config, entitlement and disposal count requests',
      (tester) async {
        await initialize();
        await tester.pumpWidget(tree());
        await tester.pump();
        expect(loads(kind).length, 1);
        for (var i = 0; i < 5; i++) {
          await tester.pumpWidget(tree());
        }
        expect(loads(kind).length, 1);
        AdMobKit.updateConfig(
          AdMobKit.config.copyWith(
            interstitialCooldown: const Duration(seconds: 45),
          ),
        );
        await tester.pump();
        expect(loads(kind).length, 1);
        AdMobKit.updateConfig(
          AdMobKit.config.copyWith(
            android: const AdPlatformConfig(
              banner: 'banner-2',
              native: 'native-2',
            ),
          ),
        );
        await tester.pump();
        expect(loads(kind).length, 2);
        AdMobKit.setEntitled(true);
        await tester.pump();
        expect(loads(kind).length, 2);
        expect(find.byType(AdWidget), findsNothing);
        AdMobKit.setEntitled(false);
        await tester.pump();
        expect(loads(kind).length, 3);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(calls.where((c) => c.method == 'disposeAd').length, 3);
      },
    );
    testWidgets('$kind waits for initialization and consent, then loads once', (
      tester,
    ) async {
      allowed = false;
      await tester.pumpWidget(tree());
      await tester.pump();
      expect(loads(kind), isEmpty);
      await initialize();
      await tester.pump();
      expect(loads(kind), isEmpty);
      allowed = true;
      await ConsentManager.instance.canRequestAds();
      await tester.pump();
      expect(loads(kind).length, 1);
      allowed = false;
      await ConsentManager.instance.canRequestAds();
      await tester.pump();
      expect(calls.where((c) => c.method == 'disposeAd').length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$kind bounded failure retry is cancelled by entitlement', (
      tester,
    ) async {
      await initialize();
      await tester.pumpWidget(tree());
      await tester.pump();
      final id = loads(kind).single.arguments['adId'] as int;
      await event(
        id,
        'onAdFailedToLoad',
        error: LoadAdError(2, 'network', 'offline', null),
      );
      await tester.pump(const Duration(seconds: 29));
      expect(loads(kind).length, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(loads(kind).length, 2);
      final next = loads(kind).last.arguments['adId'] as int;
      await event(
        next,
        'onAdFailedToLoad',
        error: LoadAdError(2, 'network', 'offline', null),
      );
      AdMobKit.setEntitled(true);
      await tester.pump(const Duration(minutes: 5));
      expect(loads(kind).length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
