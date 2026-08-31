import 'dart:async';
import 'package:flutter/material.dart';

import '../ads/app_open_ad_manager.dart';
import '../ads/interstitial_ad_manager.dart';

/// A comprehensive Paywall Close Guard widget that intercepts both the on-screen
/// close button and Android/iOS back navigation gestures.
///
/// Features:
/// - Skips ad requests entirely if the user is already entitled/subscribed ([isEntitled]).
/// - Preloads a single scoped interstitial ad on mount.
/// - Suppresses App Open ads while on the paywall screen.
/// - Never traps the user: if ad loading times out or fails, allows immediate dismissal.
///
/// ```dart
/// PaywallCloseGuard(
///   adUnitId: 'ca-app-pub-XXXX/XXXX',
///   isEntitled: user.isPremium,
///   onDismiss: () => Navigator.of(context).pop(),
///   builder: (context, attemptDismiss, isAdLoading) {
///     return Scaffold(
///       appBar: AppBar(
///         leading: IconButton(
///           icon: const Icon(Icons.close),
///           onPressed: attemptDismiss,
///         ),
///       ),
///       body: PaywallBody(),
///     );
///   },
/// )
/// ```
class PaywallCloseGuard extends StatefulWidget {
  /// The AdMob Interstitial ad unit ID for the close guard.
  final String? adUnitId;

  /// Whether the user has an active entitlement / subscription.
  /// If `true`, no ad will ever be loaded or shown.
  final bool isEntitled;

  /// Maximum time to wait for the ad to load before allowing fallback dismissal.
  final Duration timeout;

  /// Callback invoked when the paywall screen is allowed to dismiss.
  final VoidCallback onDismiss;

  /// Optional callback when close ad loads.
  final VoidCallback? onAdLoaded;

  /// Optional callback when close ad fails.
  final VoidCallback? onAdFailed;

  /// Builder that receives the dismiss trigger callback and ad loading status.
  final Widget Function(
    BuildContext context,
    VoidCallback attemptDismiss,
    bool isAdLoading,
  ) builder;

  /// Creates a [PaywallCloseGuard].
  const PaywallCloseGuard({
    super.key,
    required this.builder,
    required this.onDismiss,
    this.adUnitId,
    this.isEntitled = false,
    this.timeout = const Duration(seconds: 5),
    this.onAdLoaded,
    this.onAdFailed,
  });

  @override
  State<PaywallCloseGuard> createState() => _PaywallCloseGuardState();
}

class _PaywallCloseGuardState extends State<PaywallCloseGuard> {
  InterstitialAdManager? _manager;
  bool _isTimedOut = false;
  bool _isDismissing = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    AppOpenAdManager.isInProScreen = true;

    if (!widget.isEntitled && widget.adUnitId != null) {
      _initAdManager();
    }
  }

  void _initAdManager() {
    final manager = InterstitialAdManager();
    _manager = manager;

    manager.onAdLoadComplete = () {
      if (mounted) {
        setState(() {});
        widget.onAdLoaded?.call();
      }
    };

    manager.onAdLoadFailed = () {
      if (mounted) {
        setState(() {});
        widget.onAdFailed?.call();
      }
    };

    manager.onAdDismissed = () {
      _executeDismiss();
    };

    manager.loadAd(widget.adUnitId!);

    _timeoutTimer = Timer(widget.timeout, () {
      if (mounted) {
        setState(() => _isTimedOut = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PaywallCloseGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEntitled != widget.isEntitled && widget.isEntitled) {
      _manager?.dispose();
      _manager = null;
      _timeoutTimer?.cancel();
    }
  }

  void _attemptDismiss() {
    if (_isDismissing) return;

    // 1. Entitled users exit immediately with 0 ads
    if (widget.isEntitled || widget.adUnitId == null || _manager == null) {
      _executeDismiss();
      return;
    }

    // 2. If ad is ready, show it
    if (_manager!.isAdReady) {
      _isDismissing = true;
      final shown = _manager!.showAd();
      if (!shown) {
        _executeDismiss();
      }
      return;
    }

    // 3. If ad failed, timed out, or not ready, never trap the user
    if (_isTimedOut || !_manager!.isLoading || !_manager!.isAdReady) {
      _executeDismiss();
      return;
    }

    // 4. If still loading within timeout, dismiss gracefully
    _executeDismiss();
  }

  void _executeDismiss() {
    if (!mounted) return;
    _isDismissing = true;
    widget.onDismiss();
  }

  @override
  void dispose() {
    AppOpenAdManager.isInProScreen = false;
    _timeoutTimer?.cancel();
    _manager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !widget.isEntitled &&
        _manager != null &&
        _manager!.isLoading &&
        !_isTimedOut;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _attemptDismiss();
      },
      child: widget.builder(context, _attemptDismiss, isLoading),
    );
  }
}
