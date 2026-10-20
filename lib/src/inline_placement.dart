// ignore_for_file: prefer_initializing_formals

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'native/native_templates.dart';

/// An upcoming inline placement. Its widget must use the same unit, size and
/// style to claim the library-owned cached ad.
class InlinePlacement {
  // Explicit non-null parameters keep each constructor valid.
  const InlinePlacement.native({
    required this.adUnitId,
    required NativeTemplate template,
    this.style = const NativeAdStyle(),
  }) : template = template,
       size = null;

  const InlinePlacement.banner({required this.adUnitId, required AdSize size})
    : size = size,
      template = null,
      style = const NativeAdStyle();

  final String adUnitId;
  final NativeTemplate? template;
  final NativeAdStyle style;
  final AdSize? size;
}
