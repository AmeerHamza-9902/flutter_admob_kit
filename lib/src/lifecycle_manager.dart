import 'package:flutter/widgets.dart';

import 'ad_orchestrator.dart';
import 'app_open/app_open_manager.dart';

/// Monitors app foreground/background transitions to automatically present
/// App Open ads safely without boilerplate code.
class LifecycleManager with WidgetsBindingObserver {
  LifecycleManager({
    required this.appOpenManager,
    this.isEnabled = true,
  });

  final AppOpenManager appOpenManager;
  bool isEnabled;

  bool _isObserving = false;

  /// Starts listening to app lifecycle transitions.
  void start() {
    if (_isObserving) return;
    _isObserving = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stops listening to app lifecycle transitions.
  void stop() {
    if (!_isObserving) return;
    _isObserving = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isEnabled) return;

    if (state == AppLifecycleState.resumed) {
      // 1. Skip if another fullscreen ad is already presenting
      if (AdOrchestrator.instance.isAnyFullscreenShowing) return;

      // 2. Skip if currently in a paywall/purchase screen
      if (appOpenManager.isInPaywall) return;

      // 3. Attempt to present the primed App Open ad
      appOpenManager.show(true);
    }
  }

  void dispose() {
    stop();
  }
}
