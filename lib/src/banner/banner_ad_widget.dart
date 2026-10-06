import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../admob_kit.dart';
import '../inline_ad_retry.dart';
import '../ad_state.dart';
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
    this.fitToWidth = false,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  });

  /// Factory constructor for a standard small banner that adapts to full screen width.
  const BannerAdWidget.small({
    super.key,
    this.adUnitId,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : size = AdSize.banner,
       isAdaptive = true,
       fitToWidth = false;

  /// Factory constructor for a standard 300x250 Medium Rectangle banner
  /// displayed at its native size without scaling ad assets.
  const BannerAdWidget.mediumRectangle({
    super.key,
    this.adUnitId,
    this.fitToWidth = false,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : size = AdSize.mediumRectangle,
       isAdaptive = false;

  /// Optional override for the Banner Ad Unit ID. If omitted, uses [AdMobKit.config.bannerId].
  final String? adUnitId;

  /// The banner ad size. Defaults to [AdSize.banner].
  final AdSize size;

  /// Whether to use anchored adaptive banner sizing based on device screen width.
  final bool isAdaptive;

  /// Centers the native-size banner in available space; never scales ad assets.
  final bool fitToWidth;

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

class _BannerAdWidgetState extends State<BannerAdWidget>
    with InlineAdRetry<BannerAdWidget> {
  BannerAd? _ad;
  AdSize? _resolvedSize;
  bool _isLoaded = false;
  bool _hasFailed = false;
  int _loadGeneration = 0;
  String? _activeAdUnitId;
  bool? _activeTestMode;

  @override
  void initState() {
    super.initState();
    AdMobKit.configNotifier.addListener(_onConfigChanged);
  }

  int? _adaptiveWidth;
  int? _pendingWidth;
  bool _layoutScheduled = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !widget.isAdaptive) {
      _started = true;
      _load();
    }
  }

  void _scheduleWidth(int width) {
    if (width <= 0 || width == _adaptiveWidth) return;
    _pendingWidth = width;
    if (_layoutScheduled) return;
    _layoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutScheduled = false;
      if (!mounted || !widget.isAdaptive) return;
      final width = _pendingWidth;
      if (width == null || width == _adaptiveWidth) return;
      _adaptiveWidth = width;
      _load();
    });
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

  void _onConfigChanged() {
    if (!mounted) return;

    if (!AdMobKit.canRequestAds) {
      resetRetry();
      _loadGeneration++;
      _ad?.dispose();
      _ad = null;
      _isLoaded = false;
      _activeAdUnitId = null;
      _activeTestMode = null;
      setState(() {});
      return;
    }

    final targetUnitId = widget.adUnitId ?? AdMobKit.config.bannerId;
    final targetTestMode = AdMobKit.config.testMode;

    if (_activeAdUnitId != targetUnitId || _activeTestMode != targetTestMode) {
      _load();
    }
  }

  Future<void> _load({bool retry = false}) async {
    if (!mounted) return;
    if (widget.isAdaptive && _adaptiveWidth == null) return;
    if (!retry) resetRetry();
    final gen = ++_loadGeneration;

    if (!AdMobKit.canRequestAds) {
      _ad?.dispose();
      _ad = null;
      _isLoaded = false;
      _activeAdUnitId = null;
      _activeTestMode = null;
      if (mounted) setState(() {});
      return;
    }

    final unitId = widget.adUnitId ?? AdMobKit.config.bannerId;
    final testMode = AdMobKit.config.testMode;
    if (unitId == null || unitId.isEmpty) {
      _ad?.dispose();
      _ad = null;
      setState(() {
        _isLoaded = false;
        _hasFailed = true;
      });
      _activeAdUnitId = unitId;
      _activeTestMode = testMode;
      return;
    }

    _ad?.dispose();
    _ad = null;
    _isLoaded = false;
    _hasFailed = false;
    _activeAdUnitId = unitId;
    _activeTestMode = testMode;
    if (mounted) setState(() {});

    AdSize targetSize = widget.size;
    if (widget.isAdaptive && mounted) {
      final width = _adaptiveWidth!;
      targetSize = await BannerManager.getAdaptiveSize(width);
      if (gen != _loadGeneration || !mounted || !AdMobKit.canRequestAds) return;
    }
    _resolvedSize = targetSize;

    final banner = BannerAd(
      adUnitId: unitId,
      size: targetSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdImpression: (_) {
          if (mounted && gen == _loadGeneration && AdMobKit.canRequestAds) {
            AdMobKit.reportEvent(
              AdEvent(
                format: AdFormat.banner,
                type: AdEventType.impression,
                timestamp: DateTime.now(),
                adUnitId: unitId,
              ),
            );
          }
        },
        onAdClicked: (_) {
          if (mounted && gen == _loadGeneration && AdMobKit.canRequestAds) {
            AdMobKit.reportEvent(
              AdEvent(
                format: AdFormat.banner,
                type: AdEventType.clicked,
                timestamp: DateTime.now(),
                adUnitId: unitId,
              ),
            );
          }
        },
        onAdLoaded: (ad) {
          if (gen != _loadGeneration || !mounted || !AdMobKit.canRequestAds) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as BannerAd;
            _isLoaded = true;
            _hasFailed = false;
          });
          resetRetry();
          AdMobKit.reportEvent(
            AdEvent(
              format: AdFormat.banner,
              type: AdEventType.loaded,
              timestamp: DateTime.now(),
              adUnitId: unitId,
            ),
          );
          widget.onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (gen != _loadGeneration || !mounted || !AdMobKit.canRequestAds) {
            return;
          }
          setState(() {
            _ad = null;
            _isLoaded = false;
            _hasFailed = true;
          });
          retryLoad(() => _load(retry: true));
          widget.onAdFailed?.call();
        },
      ),
    );

    _ad = banner;
    try {
      await banner.load();
    } catch (_) {
      await banner.dispose();
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _ad = null;
        _isLoaded = false;
        _hasFailed = true;
      });
      retryLoad(() => _load(retry: true));
      widget.onAdFailed?.call();
    }
  }

  @override
  void dispose() {
    AdMobKit.configNotifier.removeListener(_onConfigChanged);
    _loadGeneration++;
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdaptive) return _buildContent(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        _scheduleWidth(width.truncate());
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!AdMobKit.canRequestAds || _hasFailed) {
      return const SizedBox.shrink();
    }

    final width = (_resolvedSize ?? widget.size).width.toDouble();
    final height = (_resolvedSize ?? widget.size).height.toDouble();

    Widget content;
    if (_isLoaded && _ad != null) {
      content = SizedBox(
        width: width,
        height: height,
        child: AdWidget(ad: _ad!),
      );
    } else if (widget.placeholder != null) {
      content = widget.placeholder!;
    } else if (widget.showShimmer) {
      content = AdShimmerPlaceholder(
        width: width,
        height: height,
        variant: height >= 200
            ? AdShimmerVariant.mediumRectangle
            : AdShimmerVariant.banner,
      );
    } else {
      content = SizedBox(width: width, height: height);
    }

    if (widget.fitToWidth) {
      return Center(child: content);
    }

    return content;
  }
}
