import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages User Messaging Platform (UMP) consent flows for GDPR and privacy compliance.
class ConsentManager {
  ConsentManager._();

  static final ConsentManager instance = ConsentManager._();

  /// Requests a consent information update and presents the form if required.
  ///
  /// Safe to call on every app launch. Completes without throwing even if
  /// consent request fails or network is absent.
  Future<bool> requestConsent({
    ConsentRequestParameters? parameters,
  }) async {
    final completer = Completer<bool>();
    final params = parameters ?? ConsentRequestParameters();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          ConsentForm.loadAndShowConsentFormIfRequired(
            (formError) {
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
          debugPrint(
            'flutter_admob_kit: UMP consent info update failed: ${formError.message}',
          );
          completer.complete(false);
        },
      );
    } catch (e) {
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
          debugPrint('flutter_admob_kit: Privacy options error: ${formError.message}');
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

  /// Checks if user consent has been obtained or is not required.
  Future<bool> canRequestAds() async {
    try {
      final status = await ConsentInformation.instance.getConsentStatus();
      return status == ConsentStatus.obtained ||
          status == ConsentStatus.notRequired;
    } catch (_) {
      // Default to allowing ad requests if consent status is unknown
      return true;
    }
  }

  /// Resets consent status (useful during testing).
  @visibleForTesting
  Future<void> reset() async {
    try {
      await ConsentInformation.instance.reset();
    } catch (_) {}
  }
}
