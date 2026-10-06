import 'package:flutter/widgets.dart';

import 'ad_orchestrator.dart';
import 'app_open/app_open_manager.dart';

/// Monitors app foreground/background transitions to automatically present
/// App Open ads safely without boilerplate code.
class LifecycleManager with WidgetsBindingObserver {
  LifecycleManager({required this.appOpenManager, this.isEnabled = true});

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

  bool _wasInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInBackground = !AdOrchestrator.instance.isAnyFullscreenShowing;
    } else if (state == AppLifecycleState.resumed) {
      if (!_wasInBackground) return;
      _wasInBackground = false;

      if (!isEnabled) return;

      if (AdOrchestrator.instance.isAnyFullscreenShowing) return;

      if (appOpenManager.isInPaywall) return;

      appOpenManager.show(true);
    }
  }

  void dispose() {
    stop();
  }
}
