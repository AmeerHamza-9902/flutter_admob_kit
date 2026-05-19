import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  final String adUnitId;

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
    required this.adUnitId,
    this.size = AdSize.banner,
    this.onAdLoaded,
    this.onAdLoadFailed,
    this.onAdClicked,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
          widget.onAdLoaded?.call();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          _ad = null;
          if (mounted) setState(() => _loaded = false);
          widget.onAdLoadFailed?.call();
        },
        onAdClicked: (_) => widget.onAdClicked?.call(),
      ),
    )..load();
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
