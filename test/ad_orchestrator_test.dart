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
      final acquired = AdOrchestrator.instance.tryAcquire('interstitial');
      expect(acquired, isTrue);
      expect(AdOrchestrator.instance.isAnyFullscreenShowing, isTrue);
      expect(AdOrchestrator.instance.activeFormat, 'interstitial');
    });

    test('blocks concurrent presentation of different ad formats', () {
      // 1. Interstitial acquires lock
      expect(AdOrchestrator.instance.tryAcquire('interstitial'), isTrue);

      // 2. App Open attempts to acquire — blocked!
      expect(AdOrchestrator.instance.tryAcquire('app_open'), isFalse);

      // 3. Rewarded attempts to acquire — blocked!
      expect(AdOrchestrator.instance.tryAcquire('rewarded'), isFalse);

      expect(AdOrchestrator.instance.activeFormat, 'interstitial');
    });

    test('releasing lock allows next format to acquire', () {
      expect(AdOrchestrator.instance.tryAcquire('interstitial'), isTrue);
      AdOrchestrator.instance.release('interstitial');

      expect(AdOrchestrator.instance.isAnyFullscreenShowing, isFalse);
      expect(AdOrchestrator.instance.activeFormat, isNull);

      // Now App Open can acquire cleanly
      expect(AdOrchestrator.instance.tryAcquire('app_open'), isTrue);
      expect(AdOrchestrator.instance.activeFormat, 'app_open');
    });
  });
}
