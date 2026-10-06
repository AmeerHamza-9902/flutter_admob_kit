import 'dart:async';
import 'package:flutter/widgets.dart';
import 'admob_kit.dart';
import 'retry_policy.dart';

/// One bounded retry timer per mounted placement; never driven by build().
mixin InlineAdRetry<T extends StatefulWidget> on State<T> {
  Timer? _retryTimer;
  int _attempt = 0;
  int _retryGeneration = 0;

  void resetRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _attempt = 0;
    _retryGeneration++;
  }

  void retryLoad(VoidCallback load) {
    const policy = RetryPolicy();
    if (!mounted ||
        !AdMobKit.canRequestAds ||
        _retryTimer != null ||
        !policy.shouldRetry(++_attempt)) {
      return;
    }
    final generation = _retryGeneration;
    _retryTimer = Timer(policy.delayFor(_attempt), () {
      _retryTimer = null;
      if (mounted && generation == _retryGeneration && AdMobKit.canRequestAds) {
        load();
      }
    });
  }

  @override
  void dispose() {
    resetRetry();
    super.dispose();
  }
}
