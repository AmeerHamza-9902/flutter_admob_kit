import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../admob_kit.dart';
import '../inline_preload.dart';
import '../inline_ad_retry.dart';
import '../ad_state.dart';
import '../widgets/ad_shimmer_placeholder.dart';
import 'banner_manager.dart';
import 'banner_preload_controller.dart';

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
    this.isInlineAdaptive = false,
    this.maxHeight = 250,
    this.fitToWidth = false,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : assert(maxHeight >= 50),
       assert(!isAdaptive || !isInlineAdaptive);

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
       isInlineAdaptive = false,
       maxHeight = 50,
       fitToWidth = false;

  /// Standard 320x100 large banner, fitted proportionally to available width.
  /// Set [fitToWidth] to false to retain its native dimensions.
  const BannerAdWidget.large({
    super.key,
    this.adUnitId,
    this.fitToWidth = true,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : size = AdSize.largeBanner,
       isAdaptive = false,
       isInlineAdaptive = false,
       maxHeight = 100;

  /// Factory constructor for a standard 300x250 Medium Rectangle banner
  /// Use [fitToWidth] to scale proportionally to the available width.
  const BannerAdWidget.mediumRectangle({
    super.key,
    this.adUnitId,
    this.fitToWidth = true,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : size = AdSize.mediumRectangle,
       isAdaptive = false,
       isInlineAdaptive = false,
       maxHeight = 250;

  /// Full-width inline banner, with a default maximum height of 50dp.
  /// Place in scrolling content; the SDK returns the actual loaded height.
  const BannerAdWidget.inlineAdaptive({
    super.key,
    this.adUnitId,
    this.maxHeight = 50,
    this.fitToWidth = false,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : assert(maxHeight >= 50),
       size = AdSize.banner,
       isAdaptive = false,
       isInlineAdaptive = true;

  /// Full-width inline banner, with a default maximum height of 250dp.
  const BannerAdWidget.inlineAdaptiveLarge({
    super.key,
    this.adUnitId,
    this.maxHeight = 250,
    this.fitToWidth = false,
    this.showShimmer = true,
    this.placeholder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : assert(maxHeight >= 50),
       size = AdSize.mediumRectangle,
       isAdaptive = false,
       isInlineAdaptive = true;

  /// Optional override for the Banner Ad Unit ID. If omitted, uses the
  /// configured banner unit ID.
  final String? adUnitId;

  /// The banner ad size. Defaults to [AdSize.banner].
  final AdSize size;

  /// Whether to use anchored adaptive banner sizing based on device screen width.
  final bool isAdaptive;

  /// Use full-width SDK sizing for inline banners in scrolling content.
  final bool isInlineAdaptive;

  /// Maximum requested inline height in dp; the SDK determines actual height.
  final int maxHeight;

  /// Scales the banner proportionally with FittedBox to fill available width.
  /// Its displayed height scales too. Adaptive banners already request full width.
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
  BannerPreloadController? _claimController;
  Object? _claimToken;
  void Function()? _releasePreload;

  void _cancelClaim() {
    _releasePreload?.call();
    _releasePreload = null;
    final token = _claimToken;
    if (token != null) _claimController?.cancelClaim(token);
    _claimController = null;
    _claimToken = null;
  }

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

  bool get _usesWidth => widget.isAdaptive || widget.isInlineAdaptive;

  int? _adaptiveWidth;
  int? _pendingWidth;
  bool _layoutScheduled = false;
  bool _reloadForLayout = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !_usesWidth) {
      _started = true;
      _load();
    }
  }

  void _scheduleWidth(int width) {
    if (width <= 0 || (width == _adaptiveWidth && !_reloadForLayout)) return;
    _pendingWidth = width;
    if (_layoutScheduled) return;
    _layoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutScheduled = false;
      if (!mounted || !_usesWidth) return;
      final width = _pendingWidth;
      if (width == null || (width == _adaptiveWidth && !_reloadForLayout)) {
        return;
      }
      _reloadForLayout = false;
      _adaptiveWidth = width;
      _load();
    });
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId ||
        oldWidget.size != widget.size ||
        oldWidget.isAdaptive != widget.isAdaptive ||
        oldWidget.isInlineAdaptive != widget.isInlineAdaptive ||
        (widget.isInlineAdaptive && oldWidget.maxHeight != widget.maxHeight)) {
      if (_usesWidth) {
        _reloadForLayout = true;
      } else {
        _reloadForLayout = false;
        _load();
      }
    }
  }

  void _onConfigChanged() {
    if (!mounted) return;

    if (!AdMobKit.canRequestAds) {
      _cancelClaim();
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
    if (_usesWidth && _adaptiveWidth == null) return;
    _cancelClaim();
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
    if (widget.isInlineAdaptive) {
      targetSize = AdSize.getInlineAdaptiveBannerAdSize(
        _adaptiveWidth!,
        widget.maxHeight,
      );
    } else if (widget.isAdaptive && mounted) {
      final width = _adaptiveWidth!;
      targetSize = await BannerManager.getAdaptiveSize(width);
      if (gen != _loadGeneration || !mounted || !AdMobKit.canRequestAds) return;
    }
    _resolvedSize = targetSize;
    final managed = InlinePreload.enabled;
    final preload = managed
        ? InlinePreload.bannerCache(targetSize, unitId)
        : null;
    if (preload != null) {
      if (managed) {
        final ready = await preload.preload(size: targetSize, adUnitId: unitId);
        if (!mounted || gen != _loadGeneration || !AdMobKit.canRequestAds) {
          return;
        }
        if (!ready) {
          setState(() => _hasFailed = true);
          retryLoad(() => _load(retry: true));
          widget.onAdFailed?.call();
          return;
        }
      }
      final token = Object();
      _claimController = preload;
      _claimToken = token;
      final cached = await preload.take(targetSize, unitId, owner: token);
      if (identical(_claimToken, token)) {
        _claimController = null;
        _claimToken = null;
      }
      if (!mounted || gen != _loadGeneration || !AdMobKit.canRequestAds) {
        cached?.release();
        cached?.ad.dispose();
        return;
      }
      if (cached != null) {
        setState(() {
          _ad = cached.ad;
          _releasePreload = cached.release;
          _resolvedSize = cached.size;
          _isLoaded = true;
          _hasFailed = false;
        });
        if (managed) {
          InlinePreload.replenishBanner(
            targetSize,
            unitId,
            canRequestAds: AdMobKit.canRequestAds,
          );
        }
        widget.onAdLoaded?.call();
        return;
      }
    }

    AdMobKit.reportEvent(
      AdEvent(
        format: AdFormat.banner,
        type: AdEventType.request,
        timestamp: DateTime.now(),
        adUnitId: unitId,
      ),
    );

    final banner = BannerAd(
      adUnitId: unitId,
      size: targetSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onPaidEvent: (_, valueMicros, precision, currencyCode) {
          if (mounted && gen == _loadGeneration) {
            AdMobKit.reportEvent(
              AdEvent(
                format: AdFormat.banner,
                type: AdEventType.paid,
                timestamp: DateTime.now(),
                adUnitId: unitId,
                valueMicros: valueMicros,
                currencyCode: currencyCode,
                precision: precision.name,
              ),
            );
          }
        },
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
        onAdLoaded: (ad) async {
          if (gen != _loadGeneration || !mounted || !AdMobKit.canRequestAds) {
            ad.dispose();
            return;
          }
          if (widget.isInlineAdaptive) {
            AdSize? platformSize;
            try {
              platformSize = await (ad as BannerAd).getPlatformAdSize();
            } catch (_) {
              platformSize = null;
            }
            if (gen != _loadGeneration || !mounted || !AdMobKit.canRequestAds) {
              ad.dispose();
              return;
            }
            if (platformSize == null ||
                platformSize.width <= 0 ||
                platformSize.height <= 0) {
              ad.dispose();
              setState(() {
                _ad = null;
                _isLoaded = false;
                _hasFailed = true;
              });
              retryLoad(() => _load(retry: true));
              widget.onAdFailed?.call();
              return;
            }
            _resolvedSize = platformSize;
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
          AdMobKit.reportEvent(
            AdEvent(
              format: AdFormat.banner,
              type: AdEventType.loadFailed,
              timestamp: DateTime.now(),
              adUnitId: unitId,
              errorMessage: error.message,
            ),
          );
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
    } catch (error) {
      await banner.dispose();
      if (!mounted || gen != _loadGeneration) return;
      AdMobKit.reportEvent(
        AdEvent(
          format: AdFormat.banner,
          type: AdEventType.loadFailed,
          timestamp: DateTime.now(),
          adUnitId: unitId,
          errorMessage: '$error',
        ),
      );
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
    _cancelClaim();
    AdMobKit.configNotifier.removeListener(_onConfigChanged);
    _loadGeneration++;
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_usesWidth) return _buildContent(context);
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
    final resolvedHeight = (_resolvedSize ?? widget.size).height;
    final height =
        (widget.isInlineAdaptive && !_isLoaded
                ? widget.maxHeight
                : resolvedHeight)
            .toDouble();

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
      return LayoutBuilder(
        builder: (context, constraints) {
          final targetWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : width;
          return SizedBox(
            width: targetWidth,
            height: height * targetWidth / width,
            child: FittedBox(fit: BoxFit.fitWidth, child: content),
          );
        },
      );
    }

    return content;
  }
}
