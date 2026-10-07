import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Includes SDK sizing parameters that [AdSize.operator ==] omits.
String bannerSizeKey(AdSize size) {
  final detail = switch (size) {
    InlineAdaptiveSize inline => '${inline.maxHeight}:${inline.orientation}',
    AnchoredAdaptiveBannerAdSize anchored => '${anchored.orientation}',
    // Keep legacy SmartBanner orientations distinct for existing callers.
    // ignore: deprecated_member_use
    SmartBannerAdSize smart => '${smart.orientation}',
    _ => '',
  };
  return '${size.runtimeType}:${size.width}:${size.height}:$detail';
}
