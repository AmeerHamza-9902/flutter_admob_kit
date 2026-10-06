import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_orchestrator.dart';

/// Owns UMP forms and the shared permission to request ads.
class ConsentManager extends ChangeNotifier {
  ConsentManager._();

  static final ConsentManager instance = ConsentManager._();

  Future<bool>? _inFlightConsent;
  bool _privacyFormActive = false;
  bool _allowed = false;
  bool _privacyOptionsRequired = false;
  String? _lastError;
  int _generation = 0;

  bool get isConsentSafe => _allowed;
  bool get isBusy => _inFlightConsent != null;
  bool get isPrivacyOptionsRequired => _privacyOptionsRequired;

  /// Last UMP error, or null after a successful operation.
  String? get lastError => _lastError;

  /// Updates UMP and shows Google's consent form only when required.
  /// Returns the SDK's permission to request ads, including error recovery.
  Future<bool> requestConsent({ConsentRequestParameters? parameters}) {
    final pending = _inFlightConsent;
    if (pending != null) {
      return _privacyFormActive ? pending.then((_) => _allowed) : pending;
    }
    if (AdOrchestrator.instance.isAnyFullscreenShowing) {
      return Future.value(false);
    }

    final completion = Completer<bool>();
    _inFlightConsent = completion.future;
    final gen = ++_generation;
    _allowed = false;
    _lastError = null;
    notifyListeners();
    var finishing = false;
    Future<void> finish([String? error]) async {
      if (finishing) return;
      finishing = true;
      final allowed = await _refresh(gen, notify: false);
      if (gen == _generation) {
        _lastError = error ?? _lastError;
        _inFlightConsent = null;
        notifyListeners();
      }
      completion.complete(allowed);
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        parameters ?? ConsentRequestParameters(),
        () async {
          if (gen != _generation) {
            await finish();
            return;
          }
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((error) {
              unawaited(finish(error?.message));
            });
          } catch (error) {
            await finish('$error');
          }
        },
        (error) => unawaited(finish(error.message)),
      );
    } catch (error) {
      unawaited(finish('$error'));
    }
    return completion.future;
  }

  /// Opens required privacy choices from an explicit settings action.
  /// Repeated taps share one form; a pending initial flow completes first.
  Future<bool> showPrivacyOptionsForm() {
    final pending = _inFlightConsent;
    if (pending != null) {
      if (_privacyFormActive) return pending;
      final gen = _generation;
      return pending.then(
        (_) => (gen == _generation || _privacyFormActive)
            ? showPrivacyOptionsForm()
            : Future.value(false),
      );
    }
    if (!_privacyOptionsRequired ||
        AdOrchestrator.instance.isAnyFullscreenShowing) {
      return Future.value(false);
    }

    final completion = Completer<bool>();
    _inFlightConsent = completion.future;
    _privacyFormActive = true;
    final gen = ++_generation;
    _allowed = false;
    _lastError = null;
    notifyListeners();
    unawaited(_showPrivacyOptions(gen, completion));
    return completion.future;
  }

  Future<void> _showPrivacyOptions(int gen, Completer<bool> completion) async {
    String? error;
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        error = formError?.message;
      });
    } catch (exception) {
      error = '$exception';
    }
    await _refresh(gen, notify: false);
    if (gen != _generation) {
      completion.complete(false);
      return;
    }
    _lastError = error ?? _lastError;
    _privacyFormActive = false;
    _inFlightConsent = null;
    notifyListeners();
    completion.complete(error == null);
  }

  /// Refreshes official UMP permission and privacy-entry-point requirements.
  Future<bool> canRequestAds() async {
    if (isBusy) return false;
    return _refresh(_generation);
  }

  Future<bool> _refresh(int gen, {bool notify = true}) async {
    if (gen != _generation) return false;
    var allowed = false;
    var required = _privacyOptionsRequired;
    String? error;
    try {
      allowed = await ConsentInformation.instance.canRequestAds();
    } catch (exception) {
      error = '$exception';
    }
    try {
      required =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (exception) {
      error ??= '$exception';
    }
    if (gen != _generation) return false;
    final changed =
        _allowed != allowed ||
        _privacyOptionsRequired != required ||
        _lastError != error;
    _allowed = allowed;
    _privacyOptionsRequired = required;
    _lastError = error;
    if (notify && changed) notifyListeners();
    return allowed;
  }

  @visibleForTesting
  Future<void> reset() async {
    _generation++;
    _inFlightConsent = null;
    _privacyFormActive = false;
    _allowed = false;
    _privacyOptionsRequired = false;
    _lastError = null;
    notifyListeners();
    try {
      await ConsentInformation.instance.reset();
    } catch (_) {
      // Tests may run without a registered native UMP plugin.
    }
  }
}
