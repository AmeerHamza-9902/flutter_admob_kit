import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Helper methods for banner ad sizing and adaptive calculations.
class BannerManager {
  const BannerManager._();

  /// Calculates an anchored adaptive banner size for the given [width].
  ///
  /// Falls back to [AdSize.banner] if adaptive calculation is unavailable.
  static Future<AdSize> getAdaptiveSize(int width) async {
    try {
      final adaptive = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      return adaptive ?? AdSize.banner;
    } catch (_) {
      return AdSize.banner;
    }
  }
}
