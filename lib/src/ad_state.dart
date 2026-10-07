/// Represents the lifecycle state of an advertisement.
enum AdState {
  /// No ad is currently loading or ready.
  idle,

  /// An ad request is in flight.
  loading,

  /// An ad is loaded in memory, fresh, and ready to be shown.
  ready,

  /// The ad is currently presenting on screen.
  showing,

  /// The manager or ad object has been disposed.
  disposed,
}

/// The core ad formats supported by the SDK.
enum AdFormat { interstitial, rewarded, appOpen, banner, native }

/// Event types emitted during the lifecycle of an advertisement.
enum AdEventType {
  request,
  loaded,
  loadFailed,
  cacheHit,
  cacheMiss,
  opportunity,
  presentationAccepted,
  presentationFailed,
  expired,
  invalidated,
  waitTimedOut,
  skipped,
  shown,
  dismissed,
  clicked,
  impression,
  rewardEarned,
}

/// Lightweight data model representing an ad lifecycle event.
class AdEvent {
  const AdEvent({
    required this.format,
    required this.type,
    required this.timestamp,
    this.adUnitId,
    this.errorMessage,
    this.rewardAmount,
    this.rewardType,
    this.reason,
  });

  final AdFormat format;
  final AdEventType type;
  final DateTime timestamp;
  final String? adUnitId;
  final String? errorMessage;
  final num? rewardAmount;
  final String? rewardType;

  /// Optional local diagnostic reason; never represents an SDK impression.
  final String? reason;

  @override
  String toString() =>
      'AdEvent($format, $type, adUnitId: $adUnitId, timestamp: $timestamp)';
}
