import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ads/native_ad_manager.dart';

/// Displays a native ad managed by [NativeAdManager].
///
/// Equivalent to Swift's `GoogleNativeAdView`.
///
/// ```dart
/// ListenableBuilder(
///   listenable: nativeVM,
///   builder: (context, _) => NativeAdWidget(
///     manager: nativeVM,
///     height: 300,
///   ),
/// )
/// ```
class NativeAdWidget extends StatelessWidget {
  /// The [NativeAdManager] that owns this ad.
  final NativeAdManager manager;

  /// Height of the native ad container.
  final double height;

  /// Widget shown while the ad is loading.
  final Widget? placeholder;

  /// Creates a [NativeAdWidget].
  const NativeAdWidget({
    super.key,
    required this.manager,
    this.height = 300,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (!manager.isAdReady || manager.ad == null) {
      return placeholder ??
          SizedBox(height: manager.isLoading ? height : 0);
    }
    return SizedBox(
      height: height,
      child: AdWidget(ad: manager.ad!),
    );
  }
}
