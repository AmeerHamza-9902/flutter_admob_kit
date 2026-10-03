import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../admob_kit.dart';
import '../widgets/ad_shimmer_placeholder.dart';
import 'banner_manager.dart';

/// Drop-in, zero-boilerplate banner ad widget.
///
/// Automatically uses the configured Banner Ad Unit ID (or Google test ID in test mode),
/// handles loading, adaptive sizing, shimmer placeholders, and lifecycle disposal.
///
/// ```dart
/// const BannerAdWidget()
/// ```
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({
    super.key,
    this.adUnitId,
    this.size = AdSize.banner,
    this.isAdaptive = false,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  });

  /// Optional override for the Banner Ad Unit ID. If omitted, uses [AdMobKit.config.bannerId].
  final String? adUnitId;

  /// The banner ad size. Defaults to [AdSize.banner].
  final AdSize size;

  /// Whether to use anchored adaptive banner sizing based on device screen width.
  final bool isAdaptive;

  /// Whether to display a skeleton shimmer placeholder while the ad is loading.
  final bool showShimmer;

  /// Custom placeholder widget shown while loading.
  final Widget? placeholder;

  /// Callback when the banner ad finishes loading successfully.
  final VoidCallback? onAdLoaded;

  /// Callback when the banner ad fails to load.
  final VoidCallback? onAdFailed;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  AdSize? _resolvedSize;
  bool _isLoaded = false;
  bool _hasFailed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId ||
        oldWidget.size != widget.size ||
        oldWidget.isAdaptive != widget.isAdaptive) {
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

    final unitId = widget.adUnitId ?? AdMobKit.config.bannerId;
    if (unitId == null || unitId.isEmpty) {
      _hasFailed = true;
      widget.onAdFailed?.call();
      return;
    }

    // Dispose any previous ad
    _ad?.dispose();
    _ad = null;
    _isLoaded = false;
    _hasFailed = false;

    // Resolve adaptive size if requested
    AdSize targetSize = widget.size;
    if (widget.isAdaptive && mounted) {
      final width = MediaQuery.of(context).size.width.truncate();
      targetSize = await BannerManager.getAdaptiveSize(width);
      if (gen != _loadGeneration) return;
    }
    _resolvedSize = targetSize;

    final banner = BannerAd(
      adUnitId: unitId,
      size: targetSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (gen != _loadGeneration || !mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as BannerAd;
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

    banner.load();
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

    final width = (_resolvedSize ?? widget.size).width.toDouble();
    final height = (_resolvedSize ?? widget.size).height.toDouble();

    if (_isLoaded && _ad != null) {
      return SizedBox(
        width: width,
        height: height,
        child: AdWidget(ad: _ad!),
      );
    }

    // Loading state: placeholder or zero-CLS shimmer
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    if (widget.showShimmer) {
      return AdShimmerPlaceholder(
        width: width,
        height: height,
        variant: height >= 200
            ? AdShimmerVariant.mediumRectangle
            : AdShimmerVariant.banner,
      );
    }

    return SizedBox(width: width, height: height);
  }
}
