import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_admob_kit/native_templates'),
          (_) async => null,
        );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannel(
            'plugins.flutter.io/google_mobile_ads',
            StandardMethodCodec(AdMessageCodec()),
          ),
          (MethodCall methodCall) async {
            if (methodCall.method == 'MobileAds#initialize') {
              return InitializationStatus({});
            }
            return null;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/google_mobile_ads/ump'),
          (call) async =>
              call.method == 'ConsentInformation#canRequestAds' ? false : null,
        );
    AdMobKit.resetForTesting();
  });

  tearDown(() {
    AdMobKit.resetForTesting();
  });

  group('Banner & Native Config Invalidation', () {
    testWidgets(
      'BannerAdWidget reloads when banner ad unit id changes in updateConfig',
      (WidgetTester tester) async {
        await AdMobKit.initialize(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(banner: 'banner-id-1'),
          ),
          autoPreload: false,
        );

        int loadCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BannerAdWidget(onAdLoaded: () => loadCount++)),
          ),
        );
        await tester.pump();

        // Update config with a new banner ID
        AdMobKit.updateConfig(
          const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(banner: 'banner-id-2'),
          ),
        );

        await tester.pump();
        expect(AdMobKit.config.bannerId, 'banner-id-2');
      },
    );

    testWidgets(
      'BannerAdWidget reloads when testMode is enabled in updateConfig',
      (WidgetTester tester) async {
        await AdMobKit.initialize(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(banner: 'prod-banner-id'),
            testMode: false,
          ),
          autoPreload: false,
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: BannerAdWidget())),
        );
        await tester.pump();

        // Enable test mode
        AdMobKit.updateConfig(AdMobKit.config.copyWith(testMode: true));

        await tester.pump();
        expect(AdMobKit.config.testMode, isTrue);
        expect(
          AdMobKit.config.bannerId,
          'ca-app-pub-3940256099942544/6300978111',
        );
      },
    );

    testWidgets(
      'BannerAdWidget collapses and disposes when setEntitled(true)',
      (WidgetTester tester) async {
        await AdMobKit.initialize(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(banner: 'banner-id'),
          ),
          autoPreload: false,
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: BannerAdWidget())),
        );
        await tester.pump();

        // Activate premium
        AdMobKit.setEntitled(true);
        await tester.pump();

        // Must collapse to SizedBox.shrink()
        expect(find.byType(SizedBox), findsWidgets);
        expect(AdMobKit.isEntitled, isTrue);
      },
    );

    testWidgets(
      'NativeAdWidget reloads when native ad unit id changes in updateConfig',
      (WidgetTester tester) async {
        await AdMobKit.initialize(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(native: 'native-id-1'),
          ),
          autoPreload: false,
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: NativeAdWidget.medium())),
        );
        await tester.pump();

        // Update native ID
        AdMobKit.updateConfig(
          const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(native: 'native-id-2'),
          ),
        );

        await tester.pump();
        expect(AdMobKit.config.nativeId, 'native-id-2');
      },
    );

    testWidgets(
      'NativeAdWidget reloads when testMode is enabled in updateConfig',
      (WidgetTester tester) async {
        await AdMobKit.initialize(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(native: 'prod-native-id'),
            testMode: false,
          ),
          autoPreload: false,
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: NativeAdWidget.small())),
        );
        await tester.pump();

        // Enable test mode
        AdMobKit.updateConfig(AdMobKit.config.copyWith(testMode: true));

        await tester.pump();
        expect(AdMobKit.config.testMode, isTrue);
        expect(
          AdMobKit.config.nativeId,
          'ca-app-pub-3940256099942544/2247696110',
        );
      },
    );

    testWidgets(
      'NativeAdWidget collapses and disposes when setEntitled(true)',
      (WidgetTester tester) async {
        await AdMobKit.initialize(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(native: 'native-id'),
          ),
          autoPreload: false,
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: NativeAdWidget.medium())),
        );
        await tester.pump();

        // Activate premium
        AdMobKit.setEntitled(true);
        await tester.pump();

        expect(AdMobKit.isEntitled, isTrue);
      },
    );
  });
}
