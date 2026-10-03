import 'dart:async';
import 'package:flutter/material.dart';

import '../ad_state.dart';
import '../admob_kit.dart';
import '../interstitial/interstitial_manager.dart';

/// A Paywall Close Guard widget that intercepts both the on-screen
/// close button and Android/iOS back navigation gestures.
///
/// Features:
/// - Skips ad requests entirely if the user is already entitled/subscribed ([isEntitled]).
/// - Preloads a scoped interstitial ad on mount.
/// - Suppresses App Open ads while on the paywall screen.
/// - Never traps the user: if ad loading times out or fails, allows immediate dismissal.
///
/// ```dart
/// PaywallCloseGuard(
///   onDismiss: () => Navigator.of(context).pop(),
///   child: Scaffold(...),
/// )
/// ```
class PaywallCloseGuard extends StatefulWidget {
  /// The AdMob Interstitial ad unit ID for the close guard.
  /// If omitted, uses [AdMobKit.config.interstitialId].
  final String? adUnitId;

  /// Whether the user has an active entitlement / subscription.
  /// If `true`, no ad will ever be loaded or shown.
  final bool isEntitled;

  /// Maximum time to wait for the interstitial to load before allowing
  /// immediate dismissal. Defaults to 5 seconds.
  final Duration timeout;

  /// Called when the paywall should be dismissed.
  final VoidCallback onDismiss;

  /// Child widget wrapped by this close guard.
  final Widget? child;

  /// Alternative builder constructor providing dismissal triggers.
  final Widget Function(
    BuildContext context,
    VoidCallback attemptDismiss,
    bool isAdLoading,
  )? builder;

  /// Called when the scoped close ad loads successfully.
  final VoidCallback? onAdLoaded;

  /// Called when the scoped close ad fails to load.
  final VoidCallback? onAdFailed;

  /// Creates a [PaywallCloseGuard] wrapping either a [child] widget or a [builder] callback.
  const PaywallCloseGuard({
    super.key,
    this.adUnitId,
    this.isEntitled = false,
    this.timeout = const Duration(seconds: 5),
    required this.onDismiss,
    this.child,
    this.builder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : assert(child != null || builder != null,
            'Either child or builder must be provided.');

  /// Creates a [PaywallCloseGuard] using a [builder] callback.
  const PaywallCloseGuard.builder({
    super.key,
    this.adUnitId,
    this.isEntitled = false,
    this.timeout = const Duration(seconds: 5),
    required this.onDismiss,
    required Widget Function(
      BuildContext context,
      VoidCallback attemptDismiss,
      bool isAdLoading,
    ) this.builder,
    this.onAdLoaded,
    this.onAdFailed,
  }) : child = null;

  /// Attempts to dismiss the closest [PaywallCloseGuard] ancestor in the widget tree.
  static void dismiss(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_PaywallCloseGuardScope>();
    if (scope != null) {
      scope.attemptDismiss();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  State<PaywallCloseGuard> createState() => _PaywallCloseGuardState();
}

class _PaywallCloseGuardScope extends InheritedWidget {
  final VoidCallback attemptDismiss;
  final bool isAdLoading;

  const _PaywallCloseGuardScope({
    required this.attemptDismiss,
    required this.isAdLoading,
    required super.child,
  });

  @override
  bool updateShouldNotify(_PaywallCloseGuardScope oldWidget) {
    return isAdLoading != oldWidget.isAdLoading;
  }
}

class _PaywallCloseGuardState extends State<PaywallCloseGuard> {
  InterstitialManager? _manager;
  bool _isTimedOut = false;
  bool _isDismissing = false;
  Timer? _timeoutTimer;

  bool get _effectiveEntitled => widget.isEntitled || AdMobKit.isEntitled;

  @override
  void initState() {
    super.initState();
    try {
      AdMobKit.appOpen.isInPaywall = true;
    } catch (_) {}

    final unitId = widget.adUnitId ?? AdMobKit.config.interstitialId;
    if (!_effectiveEntitled && unitId != null && unitId.isNotEmpty) {
      _initAdManager(unitId);
    }
  }

  void _initAdManager(String unitId) {
    final manager = InterstitialManager(
      adUnitIdProvider: () => unitId,
      cooldown: Duration.zero,
    );
    _manager = manager;

    manager.onEvent = (event) {
      if (!mounted) return;
      if (event.type == AdEventType.loaded) {
        setState(() {});
        widget.onAdLoaded?.call();
      } else if (event.type == AdEventType.loadFailed) {
        setState(() {});
        widget.onAdFailed?.call();
      } else if (event.type == AdEventType.dismissed) {
        _executeDismiss();
      }
    };

    manager.preload(unitId);

    _timeoutTimer = Timer(widget.timeout, () {
      if (mounted) {
        setState(() => _isTimedOut = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PaywallCloseGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEntitled != widget.isEntitled && _effectiveEntitled) {
      _manager?.dispose();
      _manager = null;
      _timeoutTimer?.cancel();
    }
  }

  Future<void> _attemptDismiss() async {
    if (_isDismissing) return;

    // 1. Entitled users exit immediately with zero ads
    if (_effectiveEntitled || _manager == null) {
      _executeDismiss();
      return;
    }

    // 2. If ad is ready, show it
    if (_manager!.isReady) {
      _isDismissing = true;
      final shown = await _manager!.show(true);
      if (!shown) {
        _executeDismiss();
      }
      return;
    }

    // 3. If ad failed, timed out, or not ready, never trap the user
    _executeDismiss();
  }

  void _executeDismiss() {
    if (!mounted) return;
    _isDismissing = true;
    widget.onDismiss();
  }

  @override
  void dispose() {
    try {
      AdMobKit.appOpen.isInPaywall = false;
    } catch (_) {}
    _timeoutTimer?.cancel();
    _manager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !_effectiveEntitled &&
        _manager != null &&
        _manager!.isLoading &&
        !_isTimedOut;

    final content = widget.builder != null
        ? widget.builder!(context, _attemptDismiss, isLoading)
        : widget.child!;

    return _PaywallCloseGuardScope(
      attemptDismiss: _attemptDismiss,
      isAdLoading: isLoading,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _attemptDismiss();
        },
        child: content,
      ),
    );
  }
}
