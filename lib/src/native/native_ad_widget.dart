import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../admob_kit.dart';
import '../consent_manager.dart';
import '../widgets/ad_shimmer_placeholder.dart';
import 'native_templates.dart';

/// Drop-in, zero-boilerplate Native Ad widget with built-in templates.
///
/// Automatically uses the configured Native Ad Unit ID, applies Google's official
/// native templates for Android and iOS, handles loading, zero-CLS shimmers, and disposal.
///
/// ```dart
/// const NativeAdWidget.medium()
/// const NativeAdWidget.small()
/// ```
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    this.adUnitId,
    this.template = NativeTemplate.medium,
    this.style,
    this.height,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  });

  /// Factory constructor for a medium native ad card (media view + headline + body + CTA).
  ///
  /// Height defaults to `320.0` matching Google Mobile Ads official medium template.
  const NativeAdWidget.medium({
    super.key,
    this.adUnitId,
    this.style,
    this.height = 320.0,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : template = NativeTemplate.medium;

  /// Factory constructor for a compact small native ad row (icon + headline + CTA).
  ///
  /// Height defaults to `90.0` matching Google Mobile Ads official small template.
  const NativeAdWidget.small({
    super.key,
    this.adUnitId,
    this.style,
    this.height = 90.0,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : template = NativeTemplate.small;

  /// Optional override for the Native Ad Unit ID. If omitted, uses [AdMobKit.config.nativeId].
  final String? adUnitId;

  /// The pre-built template size to render.
  final NativeTemplate template;

  /// Custom visual styling (background, text color, CTA color, corner radius).
  final NativeAdStyle? style;

  /// Container height. Defaults to 320 for medium, 90 for small.
  final double? height;

  /// Whether to display a skeleton shimmer placeholder while the ad is loading.
  final bool showShimmer;

  /// Custom placeholder widget shown while loading.
  final Widget? placeholder;

  /// Callback when the native ad finishes loading successfully.
  final VoidCallback? onAdLoaded;

  /// Callback when the native ad fails to load.
  final VoidCallback? onAdFailed;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _ad;
  bool _isLoaded = false;
  bool _hasFailed = false;
  int _loadGeneration = 0;

  double get _targetHeight {
    if (widget.height != null) return widget.height!;
    switch (widget.template) {
      case NativeTemplate.small:
        return 90.0;
      case NativeTemplate.medium:
        return 320.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NativeAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId ||
        oldWidget.template != widget.template ||
        oldWidget.style != widget.style) {
      _load();
    }
  }

  Future<void> _load() async {
    final gen = ++_loadGeneration;

    // Check entitlement (premium users see no ads)
    if (AdMobKit.isEntitled) {
      if (mounted) setState(() {});
      return;
    }

    // Check consent state
    final canRequest = await ConsentManager.instance.canRequestAds();
    if (!canRequest || gen != _loadGeneration || !mounted) {
      return;
    }

    final unitId = widget.adUnitId ?? AdMobKit.config.nativeId;
    if (unitId == null || unitId.isEmpty) {
      _hasFailed = true;
      widget.onAdFailed?.call();
      return;
    }

    _ad?.dispose();
    _ad = null;
    _isLoaded = false;
    _hasFailed = false;

    final templateStyle = (widget.style ?? const NativeAdStyle())
        .toGoogleTemplateStyle(widget.template);

    final nativeAd = NativeAd(
      adUnitId: unitId,
      nativeTemplateStyle: templateStyle,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (gen != _loadGeneration || !mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as NativeAd;
            _isLoaded = true;
            _hasFailed = false;
          });
          widget.onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (gen != _loadGeneration || !mounted) return;
          setState(() {
            _ad = null;
            _isLoaded = false;
            _hasFailed = true;
          });
          widget.onAdFailed?.call();
        },
      ),
    );

    nativeAd.load();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdMobKit.isEntitled || _hasFailed) {
      return const SizedBox.shrink();
    }

    final height = _targetHeight;

    if (_isLoaded && _ad != null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: AdWidget(ad: _ad!),
      );
    }

    // Loading state: custom placeholder or shimmer skeleton
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    if (widget.showShimmer) {
      final AdShimmerVariant variant = widget.template == NativeTemplate.small
          ? AdShimmerVariant.nativeSmall
          : AdShimmerVariant.nativeMedium;

      return AdShimmerPlaceholder(
        height: height,
        variant: variant,
        borderRadius: widget.style != null
            ? BorderRadius.circular(widget.style!.cornerRadius)
            : null,
      );
    }

    return SizedBox(height: height);
  }
}
