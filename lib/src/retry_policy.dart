import 'dart:math' as math;

/// Configurable bounded exponential backoff policy for ad request retries.
class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(minutes: 5),
    this.multiplier = 2.0,
  }) : assert(maxRetries >= 0),
       assert(multiplier >= 1);

  /// Maximum consecutive retry attempts allowed before stopping.
  final int maxRetries;

  /// Initial delay before the first retry attempt.
  final Duration initialDelay;

  /// Upper bound cap on retry delay.
  final Duration maxDelay;

  /// Exponential backoff multiplier.
  final double multiplier;

  /// Whether an attempt at [attemptNumber] (1-indexed) is permitted.
  bool shouldRetry(int attemptNumber) =>
      attemptNumber > 0 && attemptNumber <= maxRetries;

  /// Calculates the backoff duration for [attemptNumber] (1-indexed).
  ///
  /// For attempt 1: 30s
  /// For attempt 2: 60s
  /// For attempt 3: 120s (capped at [maxDelay])
  Duration delayFor(int attemptNumber) {
    if (attemptNumber <= 0) return Duration.zero;
    final exponent = math.max(0, attemptNumber - 1);
    final factor = math.pow(multiplier, exponent).toDouble();
    final calculatedMs = math
        .min(
          initialDelay.inMilliseconds * factor,
          maxDelay.inMilliseconds.toDouble(),
        )
        .round();
    final boundedMs = math.min(calculatedMs, maxDelay.inMilliseconds);
    return Duration(milliseconds: boundedMs);
  }
}
