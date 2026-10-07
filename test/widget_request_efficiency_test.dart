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
  Future<AdSize?> Function()? platformSize;
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
    platformSize = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'MobileAds#initialize') {
            return InitializationStatus({});
          }
          if (call.method == 'getAdSize') {
            return platformSize == null
                ? const AdSize(width: 360, height: 180)
                : await platformSize!();
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

  testWidgets('Android bigNative uses bundled factory and developer style', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(
      const MaterialApp(
        home: NativeAdWidget.bigNative(
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
    expect(args['factoryId'], 'flutter_admob_kit/big_native');
    expect(args['nativeTemplateStyle'], isNull);
    expect(args['customOptions']['backgroundColor'], Colors.black.toARGB32());
    expect(args['customOptions']['primaryTextColor'], Colors.white.toARGB32());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android mediumNative uses horizontal bundled factory', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: NativeAdWidget.mediumNative(
            style: NativeAdStyle(
              backgroundColor: Colors.amber,
              secondaryTextColor: Colors.black,
              callToActionColor: Colors.red,
            ),
            showShimmer: false,
          ),
        ),
      ),
    );
    await tester.pump();
    final args = loads('Native').single.arguments as Map;
    expect(args['factoryId'], 'flutter_admob_kit/medium_native');
    expect(args['nativeTemplateStyle'], isNull);
    expect(args['customOptions']['backgroundColor'], Colors.amber.toARGB32());
    expect(
      args['customOptions']['secondaryTextColor'],
      Colors.black.toARGB32(),
    );
    expect(args['customOptions']['callToActionColor'], Colors.red.toARGB32());
    expect(tester.getSize(find.byType(NativeAdWidget)).height, 128);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mediumNative shimmer fits each configured height', (
    tester,
  ) async {
    await initialize();
    for (final height in [72.0, 130.0, 220.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: NativeAdWidget.mediumNative(height: height)),
        ),
      );
      await tester.pump();
      final shimmer = find.byType(AdShimmerPlaceholder);
      expect(shimmer, findsOneWidget);
      expect(
        tester.widget<AdShimmerPlaceholder>(shimmer).variant,
        AdShimmerVariant.nativeHorizontal,
      );
      expect(tester.getSize(shimmer).height, height);
      expect(tester.takeException(), isNull);
    }
    expect(loads('Native'), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mediumNative consumes a destination preload without reloading', (
    tester,
  ) async {
    await initialize();
    final controller = NativePreloadController();
    final ready = controller.preloadMediumNative();
    await tester.pump();
    final load = loads('Native').single;
    await event(load.arguments['adId'] as int, 'onAdLoaded');
    expect(await ready, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: NativeAdWidget.mediumNative(
            preloadController: controller,
            showShimmer: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(loads('Native'), hasLength(1));
    expect(find.byType(AdWidget), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'bigNative height defaults to 280 and resizes without another request',
    (tester) async {
      await initialize();
      Future<void> show(double? height) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: NativeAdWidget.bigNative(
                height: height,
                showShimmer: true,
              ),
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
        home: NativeAdWidget.bigNative(
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
      const MaterialApp(home: NativeAdWidget.bigNative(showShimmer: false)),
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

  testWidgets(
    'inline banner uses SDK height and reloads only for changed sizing',
    (tester) async {
      await initialize();
      Widget tree(int cap) => MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            child: BannerAdWidget.inlineAdaptiveLarge(
              maxHeight: cap,
              showShimmer: false,
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree(250));
      await tester.pump();
      final args = loads('Banner').single.arguments as Map;
      final size = args['size'] as InlineAdaptiveSize;
      expect(size.width, 360);
      expect(size.maxHeight, 250);
      expect(tester.getSize(find.byType(BannerAdWidget)).height, 250);
      await event(args['adId'] as int, 'onAdLoaded');
      await tester.pump();
      expect(tester.getSize(find.byType(BannerAdWidget)).height, 180);
      await tester.pumpWidget(tree(250));
      await tester.pump();
      expect(loads('Banner'), hasLength(1));
      await tester.pumpWidget(tree(300));
      await tester.pump();
      expect(loads('Banner'), hasLength(2));
      expect(
        (loads('Banner').last.arguments['size'] as InlineAdaptiveSize)
            .maxHeight,
        300,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'simultaneous inline width and cap change requests only final size',
    (tester) async {
      await initialize();
      Widget tree(double width, int cap) => MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            child: BannerAdWidget.inlineAdaptiveLarge(maxHeight: cap),
          ),
        ),
      );
      await tester.pumpWidget(tree(320, 250));
      await tester.pump();
      await tester.pumpWidget(tree(400, 300));
      await tester.pump();
      expect(loads('Banner'), hasLength(2));
      final size = loads('Banner').last.arguments['size'] as InlineAdaptiveSize;
      expect(size.width, 400);
      expect(size.maxHeight, 300);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unmount during inline size lookup ignores stale loaded callback',
    (tester) async {
      await initialize();
      final size = Completer<AdSize?>();
      platformSize = () => size.future;
      var loaded = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              child: BannerAdWidget.inlineAdaptiveLarge(
                onAdLoaded: () => loaded++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final id = loads('Banner').single.arguments['adId'] as int;
      await event(id, 'onAdLoaded');
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      size.complete(const AdSize(width: 360, height: 200));
      await tester.pump();
      expect(loaded, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing inline platform size reports failure instead of showing zero-height ad',
    (tester) async {
      await initialize();
      platformSize = () async => null;
      var failed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              child: BannerAdWidget.inlineAdaptive(onAdFailed: () => failed++),
            ),
          ),
        ),
      );
      await tester.pump();
      final args = loads('Banner').single.arguments as Map;
      expect((args['size'] as InlineAdaptiveSize).maxHeight, 50);
      await event(args['adId'] as int, 'onAdLoaded');
      await tester.pump();
      expect(failed, 1);
      expect(find.byType(AdWidget), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('medium rectangle fits width proportionally with FittedBox', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            child: BannerAdWidget.mediumRectangle(showShimmer: false),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(BannerAdWidget)), const Size(360, 300));
    expect(find.byType(FittedBox), findsOneWidget);
    expect(loads('Banner').single.arguments['size'], AdSize.mediumRectangle);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('splash preload is shared and consumed by onboarding once', (
    tester,
  ) async {
    await initialize();
    final controller = BannerPreloadController();
    addTearDown(controller.dispose);
    final first = controller.preloadLarge();
    final second = controller.preloadLarge();
    await tester.pump();
    expect(loads('Banner'), hasLength(1));
    final id = loads('Banner').single.arguments['adId'] as int;
    await event(id, 'onAdLoaded');
    expect(await first, isTrue);
    expect(await second, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: BannerAdWidget.large(preloadController: controller),
        ),
      ),
    );
    await tester.pump();
    expect(loads('Banner'), hasLength(1));
    expect(find.byType(AdWidget), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('onboarding joins pending preload rather than requesting twice', (
    tester,
  ) async {
    await initialize();
    final controller = BannerPreloadController();
    addTearDown(controller.dispose);
    final pending = controller.preloadInlineAdaptive(width: 360);
    await tester.pump();
    final id = loads('Banner').single.arguments['adId'] as int;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            child: BannerAdWidget.inlineAdaptiveLarge(
              preloadController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(loads('Banner'), hasLength(1));
    await event(id, 'onAdLoaded');
    expect(await pending, isTrue);
    await tester.pump();
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.getSize(find.byType(BannerAdWidget)).height, 180);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('entitlement cancels pending preload and prevents new requests', (
    tester,
  ) async {
    await initialize();
    final controller = BannerPreloadController();
    addTearDown(controller.dispose);
    final pending = controller.preloadLarge();
    await tester.pump();
    AdMobKit.setEntitled(true);
    expect(await pending, isFalse);
    expect(await controller.preloadLarge(), isFalse);
    expect(loads('Banner'), hasLength(1));
  });

  testWidgets('unused preload expires without automatic replacement', (
    tester,
  ) async {
    await initialize();
    final controller = BannerPreloadController();
    addTearDown(controller.dispose);
    final pending = controller.preloadLarge();
    await tester.pump();
    final id = loads('Banner').single.arguments['adId'] as int;
    await event(id, 'onAdLoaded');
    expect(await pending, isTrue);
    await tester.pump(const Duration(minutes: 3));
    expect(await controller.take(AdSize.largeBanner, 'banner-1'), isNull);
    expect(loads('Banner'), hasLength(1));
    expect(calls.where((c) => c.method == 'disposeAd'), isNotEmpty);
  });

  testWidgets('departing onboarding disposes its pending preload reservation', (
    tester,
  ) async {
    await initialize();
    final controller = BannerPreloadController();
    addTearDown(controller.dispose);
    final pending = controller.preloadLarge();
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: BannerAdWidget.large(preloadController: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(await pending, isFalse);
    await tester.pump();
    expect(loads('Banner'), hasLength(1));
    expect(calls.where((c) => c.method == 'disposeAd'), isNotEmpty);
  });

  testWidgets('inline preload with different height cap is discarded', (
    tester,
  ) async {
    await initialize();
    final controller = BannerPreloadController();
    addTearDown(controller.dispose);
    final pending = controller.preloadInlineAdaptive(
      width: 360,
      maxHeight: 250,
    );
    await tester.pump();
    expect(
      await controller.take(
        AdSize.getInlineAdaptiveBannerAdSize(360, 50),
        'banner-1',
      ),
      isNull,
    );
    expect(await pending, isFalse);
    expect(calls.where((c) => c.method == 'disposeAd'), isNotEmpty);
  });

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
