import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _FakeAppOpenManager extends AppOpenManager {
  int showCallCount = 0;

  @override
  Future<bool> show([bool shouldShow = true]) async {
    if (!shouldShow) return false;
    showCallCount++;
    return true;
  }

  @override
  void fetchAd(String adUnitId, AppOpenAdLoadCallback callback) {}
}

void main() {
  group('LifecycleManager', () {
    setUp(() {
      AdOrchestrator.instance.reset();
    });

    test(
      'first launch resumed state does NOT trigger App Open (cold start guard)',
      () {
        final appOpen = _FakeAppOpenManager();
        final lifecycle = LifecycleManager(
          appOpenManager: appOpen,
          isEnabled: true,
        );

        // On initial app mount, lifecycle state can transition to resumed
        lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
        // App Open must NOT be shown on cold start!
        expect(appOpen.showCallCount, 0);

        lifecycle.dispose();
        appOpen.dispose();
      },
    );

    test('resumed state triggers App Open after returning from background', () {
      final appOpen = _FakeAppOpenManager();
      final lifecycle = LifecycleManager(
        appOpenManager: appOpen,
        isEnabled: true,
      );

      // App transitions to background
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Transition to resumed
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(appOpen.showCallCount, 1);

      lifecycle.dispose();
      appOpen.dispose();
    });

    test(
      'resumed state skips App Open when another fullscreen ad is showing',
      () {
        final appOpen = _FakeAppOpenManager();
        final lifecycle = LifecycleManager(
          appOpenManager: appOpen,
          isEnabled: true,
        );

        // Lock acquired by Interstitial
        AdOrchestrator.instance.acquireToken('interstitial');

        // Transition to resumed
        lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
        // App Open must NOT be shown!
        expect(appOpen.showCallCount, 0);

        lifecycle.dispose();
        appOpen.dispose();
      },
    );

    test('return from fullscreen ad does not chain an App Open ad', () {
      final appOpen = _FakeAppOpenManager();
      final lifecycle = LifecycleManager(appOpenManager: appOpen);
      final token = AdOrchestrator.instance.acquireToken('interstitial');
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      AdOrchestrator.instance.releaseWithToken(token!);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(appOpen.showCallCount, 0);
      lifecycle.dispose();
      appOpen.dispose();
    });

    test('resumed state skips App Open when inside paywall screen', () {
      final appOpen = _FakeAppOpenManager();
      appOpen.isInPaywall = true;

      final lifecycle = LifecycleManager(
        appOpenManager: appOpen,
        isEnabled: true,
      );

      // Transition to resumed
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // App Open must NOT be shown!
      expect(appOpen.showCallCount, 0);

      lifecycle.dispose();
      appOpen.dispose();
    });
  });
}
