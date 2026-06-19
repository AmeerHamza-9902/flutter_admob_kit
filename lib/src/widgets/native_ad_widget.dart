import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ads/native_ad_manager.dart';
import '../flutter_admob_kit_controller.dart';

/// Displays a native ad managed by [NativeAdManager].
///
/// Equivalent to Swift's `GoogleNativeAdView`.
///
/// ```dart
/// ListenableBuilder(
///   listenable: nativeVM,
///   builder: (context, _) => NativeAdWidget(
///     manager: nativeVM,
///     height: 300,
///   ),
/// )
/// ```
class NativeAdWidget extends StatefulWidget {
  /// The [NativeAdManager] that owns this ad.
  final NativeAdManager? manager;

  /// Optional config screen key used to create an internal manager.
  final String? screenKey;

  /// Height of the native ad container.
  final double height;

  /// Widget shown while the ad is loading.
  final Widget? placeholder;

  /// Creates a [NativeAdWidget].
  const NativeAdWidget({
    super.key,
    this.manager,
    this.screenKey,
    this.height = 300,
    this.placeholder,
  }) : assert(
          manager != null || screenKey != null,
          'Provide either manager or screenKey.',
        );

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAdManager? _ownedManager;

  NativeAdManager? get _manager => widget.manager ?? _ownedManager;

  @override
  void initState() {
    super.initState();
    _configureOwnedManager();
  }

  @override
  void didUpdateWidget(covariant NativeAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager ||
        oldWidget.screenKey != widget.screenKey) {
      _ownedManager?.dispose();
      _ownedManager = null;
      _configureOwnedManager();
    }
  }

  void _configureOwnedManager() {
    if (widget.manager != null || widget.screenKey == null) return;
    final screen = FlutterAdmobKit.instance.screenConfig(widget.screenKey!);
    if (!screen.nativeAds || screen.nativeId == null) return;
    _ownedManager = NativeAdManager(adUnitId: screen.nativeId!)
      ..addListener(_onManagerChanged)
      ..refreshAd();
  }

  void _onManagerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ownedManager
      ?..removeListener(_onManagerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = _manager;
    if (manager == null) return widget.placeholder ?? const SizedBox.shrink();
    if (!manager.isAdReady || manager.ad == null) {
      return widget.placeholder ??
          SizedBox(height: manager.isLoading ? widget.height : 0);
    }
    return SizedBox(
      height: widget.height,
      child: AdWidget(ad: manager.ad!),
    );
  }
}
