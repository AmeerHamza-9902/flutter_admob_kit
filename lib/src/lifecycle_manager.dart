import 'dart:async';

import 'package:flutter/widgets.dart';

import 'ad_orchestrator.dart';
import 'app_open/app_open_manager.dart';

/// Monitors app foreground/background transitions to automatically present
/// App Open ads safely without boilerplate code.
class LifecycleManager with WidgetsBindingObserver {
  LifecycleManager({required this.appOpenManager, this.isEnabled = true})
    : _lastPresentation = AdOrchestrator.instance.presentationGeneration;

  final AppOpenManager appOpenManager;
  bool isEnabled;

  bool _isObserving = false;

  /// Starts listening to app lifecycle transitions.
  void start() {
    if (_isObserving) return;
    _isObserving = true;
    WidgetsBinding.instance.addObserver(this);
    AdOrchestrator.instance.addListener(_syncPresentationBaseline);
  }

  /// Stops listening to app lifecycle transitions.
  void stop() {
    if (!_isObserving) return;
    _isObserving = false;
    WidgetsBinding.instance.removeObserver(this);
    AdOrchestrator.instance.removeListener(_syncPresentationBaseline);
  }

  bool _wasInBackground = false;
  bool _backgroundCycleStarted = false;
  bool _presentationSyncScheduled = false;
  int _lastPresentation;

  /// A fullscreen ad completed while the app remained in the foreground.
  ///
  /// Keep that presentation out of the next genuine background cycle. The
  /// microtask delay still lets lifecycle callbacks caused by the fullscreen
  /// ad mark the current cycle as interrupted before the baseline is advanced.
  void _syncPresentationBaseline() {
    final orchestrator = AdOrchestrator.instance;
    if (orchestrator.isAnyFullscreenShowing || _presentationSyncScheduled) {
      return;
    }
    _presentationSyncScheduled = true;
    scheduleMicrotask(() {
      _presentationSyncScheduled = false;
      if (_backgroundCycleStarted ||
          AdOrchestrator.instance.isAnyFullscreenShowing) {
        return;
      }
      _lastPresentation = AdOrchestrator.instance.presentationGeneration;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final orchestrator = AdOrchestrator.instance;
      final interrupted =
          orchestrator.isAnyFullscreenShowing ||
          orchestrator.presentationGeneration != _lastPresentation;
      if (!_backgroundCycleStarted) {
        _backgroundCycleStarted = true;
        _wasInBackground = !interrupted;
      } else if (interrupted) {
        _wasInBackground = false;
      }
      _lastPresentation = orchestrator.presentationGeneration;
    } else if (state == AppLifecycleState.resumed) {
      final generation = AdOrchestrator.instance.presentationGeneration;
      final genuineResume = _wasInBackground && generation == _lastPresentation;
      _wasInBackground = false;
      _backgroundCycleStarted = false;
      _lastPresentation = generation;
      if (!genuineResume) return;

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
