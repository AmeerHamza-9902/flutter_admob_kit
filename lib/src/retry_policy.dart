import 'dart:math' as math;

/// Configurable bounded exponential backoff policy for ad request retries.
class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 16),
    this.multiplier = 2.0,
  });

  /// Maximum consecutive retry attempts allowed before stopping.
  final int maxRetries;

  /// Initial delay before the first retry attempt.
  final Duration initialDelay;

  /// Upper bound cap on retry delay.
  final Duration maxDelay;

  /// Exponential backoff multiplier.
  final double multiplier;

  /// Whether an attempt at [attemptNumber] (1-indexed) is permitted.
  bool shouldRetry(int attemptNumber) => attemptNumber <= maxRetries;

  /// Calculates the backoff duration for [attemptNumber] (1-indexed).
  ///
  /// For attempt 1: 2s
  /// For attempt 2: 4s
  /// For attempt 3: 8s (capped at [maxDelay])
  Duration delayFor(int attemptNumber) {
    if (attemptNumber <= 0) return Duration.zero;
    final exponent = math.max(0, attemptNumber - 1);
    final factor = math.pow(multiplier, exponent).toDouble();
    final calculatedMs = (initialDelay.inMilliseconds * factor).round();
    final boundedMs = math.min(calculatedMs, maxDelay.inMilliseconds);
    return Duration(milliseconds: boundedMs);
  }
}
