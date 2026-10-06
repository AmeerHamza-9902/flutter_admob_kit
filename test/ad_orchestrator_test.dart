import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  group('AdOrchestrator', () {
    setUp(() {
      AdOrchestrator.instance.reset();
    });

    test('initial state has no active fullscreen ad', () {
      expect(AdOrchestrator.instance.isAnyFullscreenShowing, isFalse);
      expect(AdOrchestrator.instance.activeFormat, isNull);
    });

    test('successfully acquires presentation lock', () {
      final acquired = AdOrchestrator.instance.acquireToken('interstitial');
      expect(acquired, isNotNull);
      expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
      expect(AdOrchestrator.instance.activeFormat, 'interstitial');
    });

    test('blocks concurrent presentation of different ad formats', () {
      // 1. Interstitial acquires lock
      expect(AdOrchestrator.instance.acquireToken('interstitial'), isNotNull);

      // 2. App Open attempts to acquire — blocked!
      expect(AdOrchestrator.instance.acquireToken('app_open'), isNull);

      // 3. Rewarded attempts to acquire — blocked!
      expect(AdOrchestrator.instance.acquireToken('rewarded'), isNull);

      expect(AdOrchestrator.instance.activeFormat, 'interstitial');
    });

    test('releasing lock allows next format to acquire', () {
      final token = AdOrchestrator.instance.acquireToken('interstitial');
      AdOrchestrator.instance.releaseWithToken(token!);

      expect(AdOrchestrator.instance.isAnyFullscreenShowing, isFalse);
      expect(AdOrchestrator.instance.activeFormat, isNull);

      // Now App Open can acquire cleanly
      expect(AdOrchestrator.instance.acquireToken('app_open'), isNotNull);
      expect(AdOrchestrator.instance.activeFormat, 'app_open');
    });

    test(
      'token-based acquire and release prevents stale release collisions',
      () {
        final token1 = AdOrchestrator.instance.acquireToken('interstitial');
        expect(token1, isNotNull);
        expect(AdOrchestrator.instance.activeFormat, 'interstitial');

        // Second acquire fails
        final token2 = AdOrchestrator.instance.acquireToken('rewarded');
        expect(token2, isNull);

        // Stale token cannot release
        final releasedStale = AdOrchestrator.instance.releaseWithToken(9999);
        expect(releasedStale, isFalse);
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);

        // Valid token releases cleanly
        final releasedValid = AdOrchestrator.instance.releaseWithToken(token1!);
        expect(releasedValid, isTrue);
        expect(AdOrchestrator.instance.isAnyFullscreenShowing, isFalse);
      },
    );
  });
}
