import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../flutter_admob_kit_controller.dart';

/// A drop-in banner ad widget.
///
/// Equivalent to Swift's `BannerAdView`.
///
/// ```dart
/// BannerAdWidget(
///   adUnitId: 'ca-app-pub-XXXX/XXXX',
///   onAdLoadFailed: () => setState(() => _showBanner = false),
/// )
/// ```
class BannerAdWidget extends StatefulWidget {
  /// The AdMob banner ad unit ID.
  final String? adUnitId;

  /// Optional config screen key used to resolve the banner ad unit.
  final String? screenKey;

  /// The banner size. Defaults to [AdSize.banner].
  final AdSize size;

  /// Called when the ad loads successfully.
  final VoidCallback? onAdLoaded;

  /// Called when the ad fails to load. Use this to hide the container.
  final VoidCallback? onAdLoadFailed;

  /// Called when the ad is clicked.
  final VoidCallback? onAdClicked;

  /// Creates a [BannerAdWidget].
  const BannerAdWidget({
    super.key,
    this.adUnitId,
    this.screenKey,
    this.size = AdSize.banner,
    this.onAdLoaded,
    this.onAdLoadFailed,
    this.onAdClicked,
  }) : assert(
          adUnitId != null || screenKey != null,
          'Provide either adUnitId or screenKey.',
        );

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  String? _activeAdUnitId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId ||
        oldWidget.screenKey != widget.screenKey ||
        oldWidget.size != widget.size) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      _load();
    }
  }

  void _load() {
    final adUnitId = widget.adUnitId ?? _configuredAdUnitId();
    if (adUnitId == null) {
      widget.onAdLoadFailed?.call();
      return;
    }
    _activeAdUnitId = adUnitId;
    _ad = BannerAd(
      adUnitId: adUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted && _activeAdUnitId == adUnitId) {
            setState(() => _loaded = true);
          }
          widget.onAdLoaded?.call();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (_activeAdUnitId == adUnitId) {
            _ad = null;
            if (mounted) setState(() => _loaded = false);
          }
          widget.onAdLoadFailed?.call();
        },
        onAdClicked: (_) => widget.onAdClicked?.call(),
      ),
    )..load();
  }

  String? _configuredAdUnitId() {
    final screenKey = widget.screenKey;
    if (screenKey == null) return null;
    final screen = FlutterAdmobKit.instance.screenConfig(screenKey);
    return screen.bannerAds ? screen.bannerId : null;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
