import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _FakeInterstitialAd extends Fake implements InterstitialAd {
  @override
  FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;
  bool isDisposed = false;

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }

  @override
  Future<void> show() async {}
}

class _TestInterstitialManager extends InterstitialManager {
  _TestInterstitialManager({required super.adUnitIdProvider});

  @override
  void fetchAd(String adUnitId, InterstitialAdLoadCallback callback) {}
}

class _FakeRewardedAd extends Fake implements RewardedAd {
  @override
  FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;
  bool isDisposed = false;

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }

  @override
  Future<void> show({
    required OnUserEarnedRewardCallback onUserEarnedReward,
  }) async {}
}

class _TestRewardedManager extends RewardedManager {
  _TestRewardedManager({required super.adUnitIdProvider});

  @override
  void fetchAd(String adUnitId, RewardedAdLoadCallback callback) {}
}

class _FakeAppOpenAd extends Fake implements AppOpenAd {
  @override
  FullScreenContentCallback<AppOpenAd>? fullScreenContentCallback;
  bool isDisposed = false;
  bool wasShown = false;

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }

  @override
  Future<void> show() async {
    wasShown = true;
  }
}

class _TestAppOpenManager extends AppOpenManager {
  _TestAppOpenManager({required super.adUnitIdProvider});

  @override
  void fetchAd(String adUnitId, AppOpenAdLoadCallback callback) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fullscreen Mutex Stale Callback Safety', () {
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
      AdOrchestrator.instance.reset();
    });

    test(
      'stale Interstitial callback cannot unlock mutex owned by newly presented ad',
      () async {
        final manager = _TestInterstitialManager(
          adUnitIdProvider: () => 'interstitial-unit',
        );

        final fakeAd1 = _FakeInterstitialAd();
        manager.setAdForTesting(fakeAd1);

        // 1. Interstitial acquires mutex token A
        final shown = await manager.show(true);
        expect(shown, isTrue);
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'interstitial');
        final tokenA = manager.leaseToken;
        expect(tokenA, isNotNull);

        // 2. Old/stale callback is captured
        final staleCallback = fakeAd1.fullScreenContentCallback;
        expect(staleCallback, isNotNull);

        // 3. Mutex is acquired by another fullscreen ad (e.g. Rewarded with token B)
        AdOrchestrator.instance.releaseWithToken(tokenA!);
        final tokenB = AdOrchestrator.instance.acquireToken('rewarded');
        expect(tokenB, isNotNull);
        expect(tokenB, isNot(tokenA));
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'rewarded');

        // 4. Stale onAdDismissed callback from Interstitial arrives
        staleCallback!.onAdDismissedFullScreenContent!(fakeAd1);

        // 5. Current fullscreen mutex MUST remain owned by the new ad (rewarded with token B)
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'rewarded');

        // 6. Stale onAdFailedToShow callback also cannot unlock
        staleCallback.onAdFailedToShowFullScreenContent!(
          fakeAd1,
          AdError(1, 'domain', 'error'),
        );
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'rewarded');

        // Clean up
        AdOrchestrator.instance.releaseWithToken(tokenB!);
        manager.dispose();
      },
    );

    test(
      'stale Rewarded callback cannot unlock mutex owned by newly presented ad',
      () async {
        final manager = _TestRewardedManager(
          adUnitIdProvider: () => 'rewarded-unit',
        );

        final fakeAd1 = _FakeRewardedAd();
        manager.setAdForTesting(fakeAd1);

        // 1. Rewarded acquires mutex token A
        final shown = await manager.show(true);
        expect(shown, isTrue);
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'rewarded');
        final tokenA = manager.leaseToken;
        expect(tokenA, isNotNull);

        // 2. Old/stale callback is captured
        final staleCallback = fakeAd1.fullScreenContentCallback;
        expect(staleCallback, isNotNull);

        // 3. Mutex is acquired by another fullscreen ad (e.g. App Open with token B)
        AdOrchestrator.instance.releaseWithToken(tokenA!);
        final tokenB = AdOrchestrator.instance.acquireToken('app_open');
        expect(tokenB, isNotNull);
        expect(tokenB, isNot(tokenA));
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'app_open');

        // 4. Stale callback from Rewarded arrives
        staleCallback!.onAdDismissedFullScreenContent!(fakeAd1);

        // 5. Current fullscreen mutex MUST remain owned by the new ad (app_open with token B)
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'app_open');

        // Clean up
        AdOrchestrator.instance.releaseWithToken(tokenB!);
        manager.dispose();
      },
    );

    test(
      'stale AppOpen callback cannot unlock mutex owned by newly presented ad',
      () async {
        final manager = _TestAppOpenManager(
          adUnitIdProvider: () => 'appopen-unit',
        );

        final fakeAd1 = _FakeAppOpenAd();
        manager.setAdForTesting(fakeAd1);

        // 1. AppOpen acquires mutex token A
        final shown = await manager.show(true);
        expect(shown, isTrue);
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'app_open');
        final tokenA = manager.leaseToken;
        expect(tokenA, isNotNull);

        // 2. Old/stale callback is captured
        final staleCallback = fakeAd1.fullScreenContentCallback;
        expect(staleCallback, isNotNull);

        // 3. Mutex is acquired by another fullscreen ad (e.g. Interstitial with token B)
        AdOrchestrator.instance.releaseWithToken(tokenA!);
        final tokenB = AdOrchestrator.instance.acquireToken('interstitial');
        expect(tokenB, isNotNull);
        expect(tokenB, isNot(tokenA));
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'interstitial');

        // 4. Stale callback from AppOpen arrives
        staleCallback!.onAdDismissedFullScreenContent!(fakeAd1);

        // 5. Current fullscreen mutex MUST remain owned by the new ad (interstitial with token B)
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
        expect(AdOrchestrator.instance.activeFormat, 'interstitial');

        // Clean up
        AdOrchestrator.instance.releaseWithToken(tokenB!);
        manager.dispose();
      },
    );

    test('App Open rechecks paywall after an opportunity listener', () async {
      final manager = _TestAppOpenManager(
        adUnitIdProvider: () => 'appopen-unit',
      );
      final ad = _FakeAppOpenAd();
      manager.setAdForTesting(ad);
      manager.onEvent = (event) {
        if (event.type == AdEventType.opportunity) manager.enterPaywall();
      };

      expect(await manager.show(true), isFalse);
      expect(ad.wasShown, isFalse);
      expect(ad.isDisposed, isFalse);
      expect(manager.isReady, isTrue);
      expect(AdOrchestrator.instance.isAnyFullscreenShowing, isFalse);
      manager.leavePaywall();
      manager.dispose();
    });
  });
}
