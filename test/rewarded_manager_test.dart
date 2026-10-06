import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _FakeRewardedManager extends RewardedManager {
  _FakeRewardedManager({super.adUnitIdProvider, super.canRequestAdsProvider});

  int fetchCallCount = 0;
  RewardedAdLoadCallback? lastCallback;

  @override
  void fetchAd(String adUnitId, RewardedAdLoadCallback callback) {
    fetchCallCount++;
    lastCallback = callback;
  }
}

void main() {
  group('RewardedManager', () {
    setUp(() {
      AdOrchestrator.instance.reset();
    });

    test('initial state is idle and not ready', () {
      final manager = _FakeRewardedManager(
        adUnitIdProvider: () => 'test-rewarded-id',
      );
      expect(manager.state, AdState.idle);
      expect(manager.isReady, isFalse);
      expect(manager.isLoading, isFalse);
      manager.dispose();
    });

    test('show(false) does not load or show', () async {
      final manager = _FakeRewardedManager(
        adUnitIdProvider: () => 'test-rewarded-id',
      );

      final result = await manager.show(false);
      expect(result, isFalse);
      expect(manager.fetchCallCount, 0);
      expect(manager.state, AdState.idle);

      manager.dispose();
    });

    test(
      'duplicate preload calls while loading do not trigger multiple requests',
      () {
        final manager = _FakeRewardedManager(
          adUnitIdProvider: () => 'test-rewarded-id',
        );

        final future1 = manager.preload();
        expect(manager.state, AdState.loading);
        expect(manager.fetchCallCount, 1);
        expect(future1, isNotNull);

        manager.preload();
        expect(manager.fetchCallCount, 1);
        expect(manager.state, AdState.loading);

        manager.dispose();
      },
    );

    test(
      'callbacks after disposal are safely ignored and do not revive state',
      () {
        final manager = _FakeRewardedManager(
          adUnitIdProvider: () => 'test-rewarded-id',
        );

        manager.preload();
        expect(manager.state, AdState.loading);
        final callback = manager.lastCallback;
        expect(callback, isNotNull);

        manager.dispose();
        expect(manager.state, AdState.disposed);

        // Stale callback arrives
        callback!.onAdFailedToLoad(
          LoadAdError(1, 'domain', 'Network failure', null),
        );
        expect(manager.state, AdState.disposed);
      },
    );

    test('canRequestAdsProvider == false prevents preload', () async {
      bool consentAllowed = false;
      final manager = _FakeRewardedManager(
        adUnitIdProvider: () => 'test-rewarded-id',
        canRequestAdsProvider: () => consentAllowed,
      );

      final result = await manager.preload();
      expect(result, isFalse);
      expect(manager.fetchCallCount, 0);
      expect(manager.state, AdState.idle);

      consentAllowed = true;
      manager.preload();
      expect(manager.fetchCallCount, 1);
      expect(manager.state, AdState.loading);

      manager.dispose();
    });
  });
}
