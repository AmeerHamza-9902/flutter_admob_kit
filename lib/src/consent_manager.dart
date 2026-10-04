import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages User Messaging Platform (UMP) consent flows for GDPR and privacy compliance.
class ConsentManager {
  ConsentManager._();

  static final ConsentManager instance = ConsentManager._();

  Future<bool>? _inFlightConsent;

  /// Requests a consent information update and presents the form if required.
  ///
  /// Safe to call on every app launch and concurrent invocations are deduplicated.
  /// Completes without throwing even if consent request fails or network is absent.
  Future<bool> requestConsent({
    ConsentRequestParameters? parameters,
  }) async {
    if (_inFlightConsent != null) return _inFlightConsent!;

    final completer = Completer<bool>();
    _inFlightConsent = completer.future;
    final params = parameters ?? ConsentRequestParameters();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          ConsentForm.loadAndShowConsentFormIfRequired(
            (formError) {
              _inFlightConsent = null;
              if (formError != null) {
                debugPrint(
                  'flutter_admob_kit: UMP consent form error: ${formError.message}',
                );
                completer.complete(false);
              } else {
                completer.complete(true);
              }
            },
          );
        },
        (formError) {
          _inFlightConsent = null;
          debugPrint(
            'flutter_admob_kit: UMP consent info update failed: ${formError.message}',
          );
          completer.complete(false);
        },
      );
    } catch (e) {
      _inFlightConsent = null;
      debugPrint('flutter_admob_kit: UMP initialization error: $e');
      return false;
    }

    return completer.future;
  }

  /// Presents the Google Privacy Options form (e.g. from an app settings screen).
  Future<bool> showPrivacyOptionsForm() async {
    final completer = Completer<bool>();
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint(
              'flutter_admob_kit: Privacy options error: ${formError.message}');
          completer.complete(false);
        } else {
          completer.complete(true);
        }
      });
    } catch (e) {
      debugPrint('flutter_admob_kit: Failed to show privacy options form: $e');
      return false;
    }
    return completer.future;
  }

  bool _cachedCanRequestAds = false;

  /// Synchronous fast check whether ads are safe to request according to UMP consent.
  bool get isConsentSafe => _cachedCanRequestAds;

  /// Checks if Google Mobile Ads reports that ads can be requested.
  ///
  /// Uses official [ConsentInformation.instance.canRequestAds()].
  Future<bool> canRequestAds() async {
    try {
      final allowed = await ConsentInformation.instance.canRequestAds();
      _cachedCanRequestAds = allowed;
      return allowed;
    } catch (_) {
      try {
        final status = await ConsentInformation.instance.getConsentStatus();
        final allowed = status == ConsentStatus.obtained ||
            status == ConsentStatus.notRequired;
        _cachedCanRequestAds = allowed;
        return allowed;
      } catch (_) {
        _cachedCanRequestAds = false;
        return false;
      }
    }
  }

  /// Resets consent status (useful during testing).
  @visibleForTesting
  Future<void> reset() async {
    _cachedCanRequestAds = false;
    try {
      await ConsentInformation.instance.reset();
    } catch (_) {}
  }
}
