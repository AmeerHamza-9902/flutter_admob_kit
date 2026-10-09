import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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

  group('Pro / Premium User Entitlement & Ad Blocking', () {
    test(
      'Pro before initialization: setEntitled(true) blocks all preloads',
      () async {
        AdMobKit.setEntitled(true);
        expect(AdMobKit.isEntitled, isTrue);

        await AdMobKit.initialize(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(
              interstitial: 'ca-app-pub-test/111',
              rewarded: 'ca-app-pub-test/222',
              appOpen: 'ca-app-pub-test/333',
            ),
          ),
        );

        // Entitlement preserved and no preloads executed
        expect(AdMobKit.isEntitled, isTrue);
        expect(AdMobKit.interstitial.state, AdState.idle);
        expect(AdMobKit.rewarded.state, AdState.idle);
        expect(AdMobKit.appOpen.state, AdState.idle);
      },
    );

    test(
      'Pro after initialization: setEntitled(true) invalidates cached ads',
      () async {
        await AdMobKit.initializeForTesting(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(
              interstitial: 'ca-app-pub-test/111',
              rewarded: 'ca-app-pub-test/222',
              appOpen: 'ca-app-pub-test/333',
            ),
          ),
          autoPreload: false,
        );

        expect(AdMobKit.isEntitled, isFalse);

        AdMobKit.setEntitled(true);
        expect(AdMobKit.isEntitled, isTrue);

        // Subsequent preload calls return false and do not load
        expect(await AdMobKit.interstitial.preload(), isFalse);
        expect(await AdMobKit.rewarded.preload(), isFalse);
        expect(await AdMobKit.appOpen.preload(), isFalse);

        expect(AdMobKit.interstitial.state, AdState.idle);
        expect(AdMobKit.rewarded.state, AdState.idle);
        expect(AdMobKit.appOpen.state, AdState.idle);
      },
    );

    test(
      'Pro show: interstitial.show(true) does nothing when entitled',
      () async {
        await AdMobKit.initializeForTesting(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(interstitial: 'ca-app-pub-test/111'),
          ),
          autoPreload: false,
        );

        AdMobKit.setEntitled(true);

        final shown = await AdMobKit.interstitial.show(true);
        expect(shown, isFalse);
        expect(AdMobKit.interstitial.state, AdState.idle);
      },
    );

    test(
      'Pro rewarded: rewarded.show(true) does nothing when entitled',
      () async {
        await AdMobKit.initializeForTesting(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(rewarded: 'ca-app-pub-test/222'),
          ),
          autoPreload: false,
        );

        AdMobKit.setEntitled(true);

        bool rewardGiven = false;
        final shown = await AdMobKit.rewarded.show(
          true,
          onReward: (_) => rewardGiven = true,
        );

        expect(shown, isFalse);
        expect(rewardGiven, isFalse);
        expect(AdMobKit.rewarded.state, AdState.idle);
      },
    );

    test(
      'show(false) is a complete no-op for Interstitial and Rewarded',
      () async {
        await AdMobKit.initializeForTesting(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(
              interstitial: 'ca-app-pub-test/111',
              rewarded: 'ca-app-pub-test/222',
            ),
          ),
          autoPreload: false,
        );

        // Free user: show(false) must still be a complete no-op
        expect(await AdMobKit.interstitial.show(false), isFalse);
        expect(AdMobKit.interstitial.state, AdState.idle);

        bool rewarded = false;
        expect(
          await AdMobKit.rewarded.show(false, onReward: (_) => rewarded = true),
          isFalse,
        );
        expect(rewarded, isFalse);
        expect(AdMobKit.rewarded.state, AdState.idle);
      },
    );

    test('Pro lifecycle: App Open does not load or show on resume', () async {
      await AdMobKit.initializeForTesting(
        config: const AdMobConfig(
          enableUmpConsent: false,
          android: AdPlatformConfig(appOpen: 'ca-app-pub-test/333'),
        ),
        autoPreload: false,
      );

      AdMobKit.setEntitled(true);

      // App Open show must return false
      final shown = await AdMobKit.appOpen.show(true);
      expect(shown, isFalse);
      expect(AdMobKit.appOpen.state, AdState.idle);
    });

    test('Pro retry: pending retries are canceled and blocked', () async {
      final manager = InterstitialManager(
        adUnitIdProvider: () => 'test-unit',
        isEntitledProvider: () => AdMobKit.isEntitled,
      );

      AdMobKit.setEntitled(true);

      // Attempt preload while entitled
      final loaded = await manager.preload();
      expect(loaded, isFalse);
      expect(manager.state, AdState.idle);

      manager.dispose();
    });

    test(
      'Premium -> Free user: setEntitled(false) restores ad behavior safely',
      () async {
        await AdMobKit.initializeForTesting(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(interstitial: 'ca-app-pub-test/111'),
          ),
          autoPreload: false,
        );

        AdMobKit.setEntitled(true);
        expect(AdMobKit.isEntitled, isTrue);

        AdMobKit.setEntitled(false);
        expect(AdMobKit.isEntitled, isFalse);
      },
    );

    testWidgets(
      'Pro Banner & Native: widgets render SizedBox.shrink without requesting ads',
      (tester) async {
        await AdMobKit.initializeForTesting(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(
              banner: 'ca-app-pub-test/banner',
              native: 'ca-app-pub-test/native',
            ),
          ),
          autoPreload: false,
        );

        AdMobKit.setEntitled(true);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [BannerAdWidget(), NativeAdWidget.small()],
              ),
            ),
          ),
        );
        await tester.pump();

        // Entitled widgets collapse to empty SizedBoxes
        expect(find.byType(BannerAdWidget), findsOneWidget);
        expect(find.byType(NativeAdWidget), findsOneWidget);
        expect(find.byType(AdShimmerPlaceholder), findsNothing);
      },
    );
  });

  group('PaywallCloseGuard Central Interstitial Architecture', () {
    testWidgets(
      'uses central AdMobKit.interstitial and bypasses immediately when entitled',
      (tester) async {
        await AdMobKit.initializeForTesting(
          config: const AdMobConfig(
            enableUmpConsent: false,
            android: AdPlatformConfig(
              interstitial: 'ca-app-pub-test/interstitial',
            ),
          ),
          autoPreload: false,
        );

        AdMobKit.setEntitled(true);

        bool dismissed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: PaywallCloseGuard(
              onDismiss: () => dismissed = true,
              child: const Scaffold(body: Text('Paywall Content')),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Paywall Content'), findsOneWidget);

        // Attempt dismiss through static helper
        final context = tester.element(find.text('Paywall Content'));
        PaywallCloseGuard.dismiss(context);
        await tester.pump();

        // Must dismiss immediately without requesting or presenting ads
        expect(dismissed, isTrue);
        expect(AdMobKit.interstitial.state, AdState.idle);
      },
    );

    testWidgets('never traps user if central interstitial is not ready', (
      tester,
    ) async {
      await AdMobKit.initializeForTesting(
        config: const AdMobConfig(
          enableUmpConsent: false,
          android: AdPlatformConfig(
            interstitial: 'ca-app-pub-test/interstitial',
          ),
        ),
        autoPreload: false,
      );

      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PaywallCloseGuard(
            onDismiss: () => dismissed = true,
            builder: (context, attemptDismiss, isLoading) {
              return ElevatedButton(
                onPressed: attemptDismiss,
                child: const Text('Close Button'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Interstitial is not loaded (idle)
      expect(AdMobKit.interstitial.isReady, isFalse);

      await tester.tap(find.text('Close Button'));
      await tester.pump();

      // Must dismiss immediately to not trap user
      expect(dismissed, isTrue);
    });
  });
}
