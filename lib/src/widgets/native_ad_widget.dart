// lib/widgets/native_ad_widget.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../admob_kit.dart';

/// Drop-in native ad widget. Pass [screenKey] matching your config's Screens key.
///
/// Usage:
///   NativeAdWidget(screenKey: 'home_screen')
///   NativeAdWidget(screenKey: 'splash_screen', factoryId: 'listTile')
class NativeAdWidget extends StatefulWidget {
  final String screenKey;
  final String factoryId;
  final double height;

  const NativeAdWidget({
    super.key,
    required this.screenKey,
    this.factoryId = 'adFactory',
    this.height = 120,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final kit = AdMobKit.instance;
    if (!kit.isNativeEnabled(widget.screenKey)) return;
    final adUnitId = kit.getNativeId(widget.screenKey)!;
    _ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: widget.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
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
      height: widget.height,
      child: AdWidget(ad: _ad!),
    );
  }
}
