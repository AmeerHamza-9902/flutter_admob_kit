import 'package:flutter/foundation.dart';

import 'ad_state.dart';

/// One named fullscreen opportunity with platform-specific AdMob unit IDs.
///
/// Register placements once the IDs are known. The library owns their caches,
/// preloads and disposal; a placement can be updated with new IDs later.
@immutable
class FullscreenPlacement {
  const FullscreenPlacement.interstitial({
    required this.id,
    this.androidId,
    this.iosId,
  }) : format = AdFormat.interstitial;

  const FullscreenPlacement.rewarded({
    required this.id,
    this.androidId,
    this.iosId,
  }) : format = AdFormat.rewarded;

  const FullscreenPlacement.appOpen({
    required this.id,
    this.androidId,
    this.iosId,
  }) : format = AdFormat.appOpen;

  final String id;
  final AdFormat format;
  final String? androidId;
  final String? iosId;

  void validate() {
    if (id.trim().isEmpty || id == 'default') {
      throw ArgumentError.value(
        id,
        'id',
        'Use a nonempty ID other than default.',
      );
    }
    if ((androidId == null || androidId!.trim().isEmpty) &&
        (iosId == null || iosId!.trim().isEmpty)) {
      throw ArgumentError(
        'Placement "$id" needs an Android or iOS ad unit ID.',
      );
    }
    if (androidId != null && androidId!.trim().isEmpty) {
      throw ArgumentError.value(androidId, 'androidId', 'Use a nonempty ID.');
    }
    if (iosId != null && iosId!.trim().isEmpty) {
      throw ArgumentError.value(iosId, 'iosId', 'Use a nonempty ID.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FullscreenPlacement &&
      id == other.id &&
      format == other.format &&
      androidId == other.androidId &&
      iosId == other.iosId;

  @override
  int get hashCode => Object.hash(id, format, androidId, iosId);
}
