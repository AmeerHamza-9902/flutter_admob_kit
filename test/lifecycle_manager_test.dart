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

    test('resumed state triggers App Open when clear', () {
      final appOpen = _FakeAppOpenManager();
      final lifecycle = LifecycleManager(appOpenManager: appOpen, isEnabled: true);

      // Transition to resumed
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(appOpen.showCallCount, 1);

      lifecycle.dispose();
      appOpen.dispose();
    });

    test('resumed state skips App Open when another fullscreen ad is showing', () {
      final appOpen = _FakeAppOpenManager();
      final lifecycle = LifecycleManager(appOpenManager: appOpen, isEnabled: true);

      // Lock acquired by Interstitial
      AdOrchestrator.instance.tryAcquire('interstitial');

      // Transition to resumed
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // App Open must NOT be shown!
      expect(appOpen.showCallCount, 0);

      lifecycle.dispose();
      appOpen.dispose();
    });

    test('resumed state skips App Open when inside paywall screen', () {
      final appOpen = _FakeAppOpenManager();
      appOpen.isInPaywall = true;

      final lifecycle = LifecycleManager(appOpenManager: appOpen, isEnabled: true);

      // Transition to resumed
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // App Open must NOT be shown!
      expect(appOpen.showCallCount, 0);

      lifecycle.dispose();
      appOpen.dispose();
    });
  });
}
