import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../admob_kit.dart';
import '../inline_preload.dart';
import '../inline_ad_retry.dart';
import '../ad_state.dart';
import '../widgets/ad_shimmer_placeholder.dart';
import 'native_templates.dart';
import 'native_preload_controller.dart';

/// Drop-in, zero-boilerplate Native Ad widget with built-in templates.
///
/// Uses the configured Native Ad Unit ID and bundled Android/iOS layouts.
/// The small variant uses Google's official template. Owns loading and disposal.
///
/// ```dart
/// const NativeAdWidget.bigNative()
/// const NativeAdWidget.mediumNative()
/// const NativeAdWidget.small()
/// ```
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    this.adUnitId,
    this.template = NativeTemplate.bigNative,
    this.style,
    this.height,
    this.showShimmer = true,
    this.placeholder,
    this.keepAlive = true,
    this.onAdLoaded,
    this.onAdFailed,
  });

  /// Large native card with full-width media, details and CTA.
  ///
  /// Height is at least `280.0` on Android and iOS.
  const NativeAdWidget.bigNative({
    super.key,
    this.adUnitId,
    this.style,
    this.height = 280.0,
    this.showShimmer = true,
    this.placeholder,
    this.keepAlive = true,
    this.onAdLoaded,
    this.onAdFailed,
  }) : template = NativeTemplate.bigNative;

  /// Horizontal native card with 120dp media, text and CTA.
  const NativeAdWidget.mediumNative({
    super.key,
    this.adUnitId,
    this.style,
    this.height = 128.0,
    this.showShimmer = true,
    this.placeholder,
    this.keepAlive = true,
    this.onAdLoaded,
    this.onAdFailed,
  }) : template = NativeTemplate.mediumNative;

  /// Compatibility alias for the former large `medium` constructor.
  @Deprecated('Use NativeAdWidget.bigNative instead.')
  const NativeAdWidget.medium({
    super.key,
    this.adUnitId,
    this.style,
    this.height = 280.0,
    this.showShimmer = true,
    this.placeholder,
    this.keepAlive = true,
    this.onAdLoaded,
    this.onAdFailed,
  }) : template = NativeTemplate.bigNative;

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
    this.keepAlive = true,
    this.onAdLoaded,
    this.onAdFailed,
  }) : template = NativeTemplate.small;

  /// Optional override for the Native Ad Unit ID. If omitted, uses [AdMobKit.config.nativeId].
  final String? adUnitId;

  /// The pre-built template size to render.
  final NativeTemplate template;

  /// Custom visual styling (background, text color, CTA color, corner radius).
  final NativeAdStyle? style;

  /// Container height. mediumNative defaults to 128 and keeps that minimum so
  /// its video MediaView can remain at least 120x120dp after card margins.
  /// Larger values are respected; the other templates use their own minimums.
  /// Non-finite values fall back to the template minimum.
  final double? height;

  /// Whether to display a skeleton shimmer placeholder while the ad is loading.
  final bool showShimmer;

  /// Custom placeholder widget shown while loading.
  final Widget? placeholder;

  /// Whether to keep this native ad alive in scrollables or tab views.
  final bool keepAlive;

  /// Callback when the native ad finishes loading successfully.
  final VoidCallback? onAdLoaded;

  /// Callback when the native ad fails to load.
  final VoidCallback? onAdFailed;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget>
    with InlineAdRetry<NativeAdWidget>, AutomaticKeepAliveClientMixin {
  static const _templates = MethodChannel('flutter_admob_kit/native_templates');
  NativeAd? _ad;
  bool _isLoaded = false;
  bool _hasFailed = false;
  int _loadGeneration = 0;
  String? _activeAdUnitId;
  bool? _activeTestMode;
  NativePreloadController? _claimController;
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

  double get _targetHeight {
    final minimum = switch (widget.template) {
      NativeTemplate.small => 90.0,
      NativeTemplate.mediumNative => 128.0,
      NativeTemplate.bigNative || NativeTemplate.medium => 280.0,
    };
    final requested = widget.height;
    return requested != null && requested.isFinite
        ? requested.clamp(minimum, double.infinity)
        : minimum;
  }

  @override
  void initState() {
    super.initState();
    AdMobKit.configNotifier.addListener(_onConfigChanged);
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

    final targetUnitId = widget.adUnitId ?? AdMobKit.config.nativeId;
    final targetTestMode = AdMobKit.config.testMode;

    if (_activeAdUnitId != targetUnitId || _activeTestMode != targetTestMode) {
      _load();
    }
  }

  Future<void> _load({bool retry = false}) async {
    if (!mounted) return;
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

    final unitId = widget.adUnitId ?? AdMobKit.config.nativeId;
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
    _cancelClaim();
    _ad = null;
    _isLoaded = false;
    _hasFailed = false;
    _activeAdUnitId = unitId;
    _activeTestMode = testMode;
    if (mounted) setState(() {});

    final style = widget.style ?? const NativeAdStyle();
    final managed = InlinePreload.enabled;
    final controller = managed
        ? InlinePreload.nativeCache(widget.template, style, unitId)
        : null;
    if (controller != null) {
      if (managed) {
        final ready = await controller.preload(
          template: widget.template,
          style: style,
          adUnitId: unitId,
        );
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
      _claimController = controller;
      _claimToken = token;
      final claimed = await controller.take(
        template: widget.template,
        style: style,
        unit: unitId,
        owner: token,
      );
      if (!mounted || gen != _loadGeneration || !AdMobKit.canRequestAds) {
        claimed?.ad.dispose();
        controller.cancelClaim(token);
        return;
      }
      if (claimed != null) {
        _releasePreload = claimed.release;
        setState(() {
          _ad = claimed.ad;
          _isLoaded = true;
          _hasFailed = false;
        });
        resetRetry();
        if (managed) {
          InlinePreload.replenishNative(
            widget.template,
            style,
            unitId,
            canRequestAds: AdMobKit.canRequestAds,
          );
        }
        widget.onAdLoaded?.call();
        return;
      }
      _claimController = null;
      _claimToken = null;
    }
    final customTemplate =
        !kIsWeb &&
        widget.template != NativeTemplate.small &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final templateStyle = customTemplate
        ? null
        : style.toGoogleTemplateStyle(widget.template);
    if (customTemplate) {
      try {
        await _templates.invokeMethod<void>('ensureRegistered');
      } catch (_) {
        if (!mounted || gen != _loadGeneration || !AdMobKit.canRequestAds) {
          return;
        }
        setState(() => _hasFailed = true);
        widget.onAdFailed?.call();
        return;
      }
      if (!mounted || gen != _loadGeneration || !AdMobKit.canRequestAds) return;
    }

    AdMobKit.reportEvent(
      AdEvent(
        format: AdFormat.native,
        type: AdEventType.request,
        timestamp: DateTime.now(),
        adUnitId: unitId,
      ),
    );

    final nativeAd = NativeAd(
      adUnitId: unitId,
      nativeTemplateStyle: templateStyle,
      factoryId: customTemplate
          ? widget.template == NativeTemplate.mediumNative
                ? 'flutter_admob_kit/medium_native'
                : 'flutter_admob_kit/big_native'
          : null,
      customOptions: customTemplate ? style.toNativeOptions() : null,
      request: const AdRequest(),
      listener: NativeAdListener(
        onPaidEvent: (_, valueMicros, precision, currencyCode) {
          if (mounted && gen == _loadGeneration) {
            AdMobKit.reportEvent(
              AdEvent(
                format: AdFormat.native,
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
                format: AdFormat.native,
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
                format: AdFormat.native,
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
            _ad = ad as NativeAd;
            _isLoaded = true;
            _hasFailed = false;
          });
          resetRetry();
          AdMobKit.reportEvent(
            AdEvent(
              format: AdFormat.native,
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
              format: AdFormat.native,
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

    _ad = nativeAd;
    try {
      await nativeAd.load();
    } catch (error) {
      await nativeAd.dispose();
      if (!mounted || gen != _loadGeneration) return;
      AdMobKit.reportEvent(
        AdEvent(
          format: AdFormat.native,
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
    AdMobKit.configNotifier.removeListener(_onConfigChanged);
    _loadGeneration++;
    _cancelClaim();
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!AdMobKit.canRequestAds || _hasFailed) {
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

    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    if (widget.showShimmer) {
      final AdShimmerVariant variant = widget.template == NativeTemplate.small
          ? AdShimmerVariant.nativeSmall
          : widget.template == NativeTemplate.mediumNative
          ? AdShimmerVariant.nativeHorizontal
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
