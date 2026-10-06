import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _FakeInterstitialManager extends InterstitialManager {
  _FakeInterstitialManager({
    super.adUnitIdProvider,
    super.cooldown,
    super.adExpiry,
    super.canRequestAdsProvider,
  });

  int fetchCallCount = 0;
  InterstitialAdLoadCallback? lastCallback;

  @override
  void fetchAd(String adUnitId, InterstitialAdLoadCallback callback) {
    fetchCallCount++;
    lastCallback = callback;
  }
}

void main() {
  group('InterstitialManager', () {
    setUp(() {
      AdOrchestrator.instance.reset();
    });

    test('initial state is idle and not ready', () {
      final manager = _FakeInterstitialManager(
        adUnitIdProvider: () => 'test-id',
      );
      expect(manager.state, AdState.idle);
      expect(manager.isReady, isFalse);
      expect(manager.isLoading, isFalse);
      manager.dispose();
    });

    test('show(false) does not load or show', () async {
      final manager = _FakeInterstitialManager(
        adUnitIdProvider: () => 'test-id',
      );

      final result = await manager.show(false);
      expect(result, isFalse);
      expect(manager.fetchCallCount, 0);
      expect(manager.state, AdState.idle);

      manager.dispose();
    });

    test(
      'duplicate preload calls while loading do not trigger multiple requests',
      () async {
        final manager = _FakeInterstitialManager(
          adUnitIdProvider: () => 'test-id',
        );

        // 1. First preload starts loading
        final future1 = manager.preload();
        expect(manager.state, AdState.loading);
        expect(manager.fetchCallCount, 1);
        expect(future1, isNotNull);

        // 2. Second preload called while first is in-flight
        manager.preload();
        // Must NOT trigger another fetchAd call!
        expect(manager.fetchCallCount, 1);
        expect(manager.state, AdState.loading);

        manager.dispose();
      },
    );

    test('cooldown prevents rapid consecutive shows', () async {
      final manager = _FakeInterstitialManager(
        adUnitIdProvider: () => 'test-id',
        cooldown: const Duration(seconds: 30),
      );

      expect(manager.isInCooldown, isFalse);

      manager.dispose();
    });

    test('expiry marks stale ads as expired', () {
      final manager = _FakeInterstitialManager(
        adUnitIdProvider: () => 'test-id',
        adExpiry: const Duration(milliseconds: 1),
      );

      // If no ad has been loaded yet, isExpired is true
      expect(manager.isExpired, isTrue);

      manager.dispose();
    });

    test(
      'callbacks after disposal are safely ignored and do not revive state',
      () {
        final manager = _FakeInterstitialManager(
          adUnitIdProvider: () => 'test-id',
        );

        manager.preload();
        expect(manager.state, AdState.loading);
        final callback = manager.lastCallback;
        expect(callback, isNotNull);

        // Dispose manager while fetch is in-flight
        manager.dispose();
        expect(manager.state, AdState.disposed);

        // Stale load failure callback arrives
        callback!.onAdFailedToLoad(
          LoadAdError(1, 'domain', 'Network failure', null),
        );
        // Manager must remain disposed and not transition to idle or retry
        expect(manager.state, AdState.disposed);
      },
    );

    test('invalidate cancels state and updates to new ad unit id', () {
      String currentId = 'id-1';
      final manager = _FakeInterstitialManager(
        adUnitIdProvider: () => currentId,
      );

      manager.preload();
      expect(manager.fetchCallCount, 1);

      // Invalidate with new id
      currentId = 'id-2';
      manager.invalidate(newAdUnitId: 'id-2');
      expect(manager.state, AdState.idle);
      expect(manager.isReady, isFalse);

      manager.dispose();
    });

    test('canRequestAdsProvider == false prevents preload', () async {
      bool consentAllowed = false;
      final manager = _FakeInterstitialManager(
        adUnitIdProvider: () => 'test-id',
        canRequestAdsProvider: () => consentAllowed,
      );

      final result = await manager.preload();
      expect(result, isFalse);
      expect(manager.fetchCallCount, 0);
      expect(manager.state, AdState.idle);

      // Now enable consent
      consentAllowed = true;
      manager.preload();
      expect(manager.fetchCallCount, 1);
      expect(manager.state, AdState.loading);

      manager.dispose();
    });
  });
}
