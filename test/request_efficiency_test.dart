import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class TestInterstitial extends InterstitialManager {
  TestInterstitial({
    super.adUnitIdProvider,
    super.canRequestAdsProvider,
    super.isEntitledProvider,
    super.retryPolicy,
    super.adExpiry,
  });
  final callbacks = <InterstitialAdLoadCallback>[];
  @override
  void fetchAd(String id, InterstitialAdLoadCallback callback) =>
      callbacks.add(callback);
}

class TestRewarded extends RewardedManager {
  TestRewarded({
    super.adUnitIdProvider,
    super.canRequestAdsProvider,
    super.isEntitledProvider,
    super.retryPolicy,
    super.adExpiry,
  });
  final callbacks = <RewardedAdLoadCallback>[];
  @override
  void fetchAd(String id, RewardedAdLoadCallback callback) =>
      callbacks.add(callback);
}

class TestAppOpen extends AppOpenManager {
  TestAppOpen({
    super.adUnitIdProvider,
    super.canRequestAdsProvider,
    super.isEntitledProvider,
    super.retryPolicy,
    super.adExpiry,
  });
  final callbacks = <AppOpenAdLoadCallback>[];
  @override
  void fetchAd(String id, AppOpenAdLoadCallback callback) =>
      callbacks.add(callback);
}

class TestInterstitialAd extends Fake implements InterstitialAd {
  @override
  FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;
  int disposals = 0;
  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<void> show() async {}
}

class TestRewardedAd extends Fake implements RewardedAd {
  @override
  FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;
  OnUserEarnedRewardCallback? reward;
  int disposals = 0;
  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<void> show({
    required OnUserEarnedRewardCallback onUserEarnedReward,
  }) async {
    reward = onUserEarnedReward;
  }
}

class TestAppOpenAd extends Fake implements AppOpenAd {
  @override
  FullScreenContentCallback<AppOpenAd>? fullScreenContentCallback;
  int disposals = 0;
  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<void> show() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final failure = LoadAdError(2, 'network', 'unavailable', null);
  for (final format in ['interstitial', 'rewarded', 'appOpen']) {
    dynamic make({
      bool Function()? consent,
      bool Function()? entitled,
      Duration expiry = const Duration(hours: 1),
    }) => switch (format) {
      'interstitial' => TestInterstitial(
        adUnitIdProvider: () => 'unit',
        canRequestAdsProvider: consent,
        isEntitledProvider: entitled,
        adExpiry: expiry,
      ),
      'rewarded' => TestRewarded(
        adUnitIdProvider: () => 'unit',
        canRequestAdsProvider: consent,
        isEntitledProvider: entitled,
        adExpiry: expiry,
      ),
      _ => TestAppOpen(
        adUnitIdProvider: () => 'unit',
        canRequestAdsProvider: consent,
        isEntitledProvider: entitled,
        adExpiry: expiry,
      ),
    };
    dynamic ad() => switch (format) {
      'interstitial' => TestInterstitialAd(),
      'rewarded' => TestRewardedAd(),
      _ => TestAppOpenAd(),
    };
    group(format, () {
      setUp(AdOrchestrator.instance.reset);
      test(
        'slow load, repeated show/preload and show(false) make one request',
        () async {
          final dynamic manager = make();
          final Future<bool> pending = manager.preload();
          for (var i = 0; i < 20; i++) {
            manager.preload();
            expect(await manager.show(true), false);
            expect(await manager.show(false), false);
          }
          expect(manager.callbacks.length, 1);
          manager.callbacks.single.onAdLoaded(ad());
          expect(await pending, true);
          expect(await manager.preload(), true);
          expect(manager.callbacks.length, 1);
          manager.dispose();
        },
      );
      test(
        'configuration invalidation waits for native request; stale callback cannot win',
        () async {
          final dynamic manager = make();
          final Future<bool> old = manager.preload();
          manager.invalidate(force: true);
          manager.preload();
          manager.preload();
          expect(await old, false);
          expect(manager.callbacks.length, 1);
          final dynamic stale = ad();
          manager.callbacks.first.onAdLoaded(stale);
          expect(stale.disposals, 1);
          expect(manager.callbacks.length, 2);
          final Future<bool> current = manager.preload();
          manager.callbacks.first.onAdFailedToLoad(failure);
          manager.callbacks.last.onAdLoaded(ad());
          expect(await current, true);
          expect(manager.isReady, true);
          manager.dispose();
        },
      );
      test(
        'dismissal replaces once; duplicate old callback preserves new cache',
        () async {
          final dynamic manager = make();
          final dynamic first = ad();
          manager.setAdForTesting(first);
          expect(await manager.show(true), true);
          expect(await manager.show(true), false);
          expect(await manager.preload(), false);
          expect(manager.callbacks.length, 0);
          final dynamic close =
              first.fullScreenContentCallback.onAdDismissedFullScreenContent;
          close(first);
          expect(manager.callbacks.length, 1);
          final dynamic next = ad();
          manager.callbacks.single.onAdLoaded(next);
          close(first);
          expect(next.disposals, 0);
          expect(manager.isReady, true);
          expect(manager.callbacks.length, 1);
          manager.dispose();
        },
      );
      test(
        'invalidate while showing retains lease until exact close',
        () async {
          final dynamic manager = make();
          final dynamic first = ad();
          manager.setAdForTesting(first);
          await manager.show(true);
          manager.invalidate(force: true);
          expect(first.disposals, 0);
          expect(manager.isShowing, true);
          expect(AdOrchestrator.instance.acquireToken('other'), null);
          first.fullScreenContentCallback.onAdDismissedFullScreenContent(first);
          expect(AdOrchestrator.instance.isAnyFullscreenShowing, false);
          expect(manager.callbacks.length, 1);
          manager.dispose();
        },
      );
      testWidgets(
        'retry is bounded and duplicate triggers do not bypass backoff',
        (tester) async {
          final dynamic manager = make();
          manager.preload();
          manager.callbacks.last.onAdFailedToLoad(failure);
          for (var i = 0; i < 10; i++) {
            manager.preload();
            await manager.show(true);
          }
          await tester.pump(const Duration(seconds: 29));
          expect(manager.callbacks.length, 1);
          await tester.pump(const Duration(seconds: 1));
          expect(manager.callbacks.length, 2);
          manager.callbacks.last.onAdFailedToLoad(failure);
          await tester.pump(const Duration(seconds: 59));
          expect(manager.callbacks.length, 2);
          await tester.pump(const Duration(seconds: 1));
          expect(manager.callbacks.length, 3);
          manager.callbacks.last.onAdLoaded(ad());
          await tester.pump(const Duration(minutes: 10));
          expect(manager.callbacks.length, 3);
          manager.dispose();
        },
      );
      testWidgets('consent revocation during retry prevents another request', (
        tester,
      ) async {
        var consent = true;
        final dynamic manager = make(consent: () => consent);
        final Future<bool> pending = manager.preload();
        manager.callbacks.last.onAdFailedToLoad(failure);
        consent = false;
        await tester.pump(const Duration(minutes: 1));
        expect(await pending, false);
        expect(manager.callbacks.length, 1);
        manager.dispose();
      });
      test('premium during load disposes result and never retries', () async {
        var premium = false;
        final dynamic manager = make(entitled: () => premium);
        final Future<bool> pending = manager.preload();
        premium = true;
        final dynamic result = ad();
        manager.callbacks.last.onAdLoaded(result);
        expect(await pending, false);
        expect(result.disposals, 1);
        expect(await manager.show(true), false);
        expect(manager.callbacks.length, 1);
        manager.dispose();
      });
      test('expired cache is replaced once', () async {
        final dynamic manager = make(expiry: Duration.zero);
        final dynamic expired = ad();
        manager.setAdForTesting(expired);
        expect(await manager.show(true), false);
        expect(await manager.show(true), false);
        expect(expired.disposals, 1);
        expect(manager.callbacks.length, 1);
        manager.dispose();
      });
      test(
        'disposed presentation retains exclusion until close and makes no replacement',
        () async {
          final dynamic manager = make();
          final dynamic first = ad();
          manager.setAdForTesting(first);
          await manager.show(true);
          manager.dispose();
          expect(AdOrchestrator.instance.isAnyFullscreenShowing, true);
          first.fullScreenContentCallback.onAdDismissedFullScreenContent(first);
          expect(AdOrchestrator.instance.isAnyFullscreenShowing, false);
          expect(manager.callbacks.length, 0);
        },
      );
    });
  }
  test('failed presentation cannot grant a stale reward', () async {
    AdOrchestrator.instance.reset();
    final manager = TestRewarded(adUnitIdProvider: () => 'unit');
    final ad = TestRewardedAd();
    manager.setAdForTesting(ad);
    var rewards = 0;
    await manager.show(true, onReward: (_) => rewards++);
    ad.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(
      ad,
      AdError(1, 'sdk', 'failed'),
    );
    ad.reward!(ad, RewardItem(1, 'coin'));
    expect(rewards, 0);
    manager.dispose();
  });

  test('show acceptance does not emit a synthetic impression', () async {
    AdOrchestrator.instance.reset();
    final manager = TestInterstitial(adUnitIdProvider: () => 'unit');
    final ad = TestInterstitialAd();
    final events = <AdEvent>[];
    manager.onEvent = events.add;
    manager.setAdForTesting(ad);
    expect(await manager.show(true), true);
    expect(events, isEmpty);
    ad.fullScreenContentCallback!.onAdImpression!(ad);
    expect(events.single.type, AdEventType.impression);
    ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
    manager.dispose();
  });

  test('SDK reward is delivered once even after dismissal', () async {
    AdOrchestrator.instance.reset();
    final manager = TestRewarded(adUnitIdProvider: () => 'unit');
    final ad = TestRewardedAd();
    manager.setAdForTesting(ad);
    var rewards = 0;
    await manager.show(true, onReward: (_) => rewards++);
    ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
    ad.reward!(ad, RewardItem(1, 'coin'));
    ad.reward!(ad, RewardItem(1, 'coin'));
    expect(rewards, 1);
    manager.dispose();
  });
}
