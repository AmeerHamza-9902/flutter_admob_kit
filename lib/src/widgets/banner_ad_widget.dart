// lib/widgets/banner_ad_widget.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../admob_kit.dart';

/// Drop-in banner widget. Pass [screenKey] matching your config's Screens key.
///
/// Usage:
///   BannerAdWidget(screenKey: 'home_screen')
class BannerAdWidget extends StatefulWidget {
  final String screenKey;
  final AdSize size;

  const BannerAdWidget({
    super.key,
    required this.screenKey,
    this.size = AdSize.banner,
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
    final kit = AdMobKit.instance;
    if (!kit.isBannerEnabled(widget.screenKey)) return;
    final adUnitId = kit.getBannerId(widget.screenKey)!;
    _ad = BannerAd(
      adUnitId: adUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
        },
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
