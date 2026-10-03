import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  group('RetryPolicy', () {
    const policy = RetryPolicy(
      maxRetries: 3,
      initialDelay: Duration(seconds: 2),
      multiplier: 2.0,
      maxDelay: Duration(seconds: 16),
    );

    test('calculates bounded exponential backoff delays', () {
      expect(policy.delayFor(1), const Duration(seconds: 2));
      expect(policy.delayFor(2), const Duration(seconds: 4));
      expect(policy.delayFor(3), const Duration(seconds: 8));
      expect(policy.delayFor(4), const Duration(seconds: 16));
      expect(policy.delayFor(5), const Duration(seconds: 16)); // capped
    });

    test('shouldRetry stops after maxRetries', () {
      expect(policy.shouldRetry(1), isTrue);
      expect(policy.shouldRetry(2), isTrue);
      expect(policy.shouldRetry(3), isTrue);
      expect(policy.shouldRetry(4), isFalse);
    });
  });
}
