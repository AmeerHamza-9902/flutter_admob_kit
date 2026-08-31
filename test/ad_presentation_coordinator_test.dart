import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  group('AdPresentationCoordinator', () {
    late AdPresentationCoordinator coordinator;

    setUp(() {
      coordinator = AdPresentationCoordinator.instance;
      coordinator.reset();
    });

    test('initially not presenting', () {
      expect(coordinator.isPresenting, false);
      expect(coordinator.activeFormat, isNull);
    });

    test('acquires lease successfully', () {
      final acquired = coordinator.tryAcquire(format: 'interstitial');
      expect(acquired, true);
      expect(coordinator.isPresenting, true);
      expect(coordinator.activeFormat, 'interstitial');
    });

    test('prevents concurrent lease acquisition', () {
      final first = coordinator.tryAcquire(format: 'interstitial');
      expect(first, true);

      final second = coordinator.tryAcquire(format: 'app_open');
      expect(second, false);
      expect(coordinator.activeFormat, 'interstitial');
    });

    test('releases lease properly', () {
      coordinator.tryAcquire(format: 'rewarded');
      expect(coordinator.isPresenting, true);

      coordinator.release();
      expect(coordinator.isPresenting, false);
      expect(coordinator.activeFormat, isNull);

      final reacquired = coordinator.tryAcquire(format: 'app_open');
      expect(reacquired, true);
      expect(coordinator.activeFormat, 'app_open');
    });
  });
}
