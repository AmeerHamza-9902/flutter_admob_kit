import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    show InitializationStatus;
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final consent = ConsentManager.instance;
  final calls = <MethodCall>[];
  var allowed = true;
  var privacyRequired = true;
  Future<Object?> Function(MethodCall)? respond;
  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );

  setUp(() async {
    AdMobKit.resetForTesting();
    AdOrchestrator.instance.reset();
    allowed = true;
    privacyRequired = true;
    respond = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ump, (call) async {
          calls.add(call);
          if (respond != null) return respond!(call);
          return switch (call.method) {
            'ConsentInformation#canRequestAds' => allowed,
            'ConsentInformation#getPrivacyOptionsRequirementStatus' =>
              privacyRequired ? 1 : 0,
            _ => null,
          };
        });
    await consent.reset();
    calls.clear();
  });
  tearDown(AdMobKit.resetForTesting);

  test(
    'default initialization waits for actual UMP form before loading ads',
    () async {
      final form = Completer<void>();
      final formOpened = Completer<void>();
      final adCalls = <String>[];
      respond = (call) async {
        if (call.method ==
            'UserMessagingPlatform#loadAndShowConsentFormIfRequired') {
          formOpened.complete();
          await form.future;
        }
        if (call.method == 'ConsentInformation#canRequestAds') return allowed;
        if (call.method ==
            'ConsentInformation#getPrivacyOptionsRequirementStatus') {
          return 1;
        }
        return null;
      };
      final ads = MethodChannel(
        'plugins.flutter.io/google_mobile_ads',
        StandardMethodCodec(AdMessageCodec()),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ads, (call) async {
            adCalls.add(call.method);
            if (call.method == 'MobileAds#initialize') {
              return InitializationStatus({});
            }
            return null;
          });
      final parameters = ConsentRequestParameters(
        tagForUnderAgeOfConsent: true,
      );
      final initialization = AdMobKit.initialize(
        config: const AdMobConfig(
          android: AdPlatformConfig(interstitial: 'unit'),
        ),
        consentParameters: parameters,
      );
      await formOpened.future;
      expect(adCalls, isEmpty);
      expect(consent.isBusy, true);
      expect(AdMobKit.canRequestAds, false);
      expect(calls.first.arguments['params'], parameters);
      form.complete();
      await initialization;
      await Future<void>.delayed(Duration.zero);
      expect(adCalls.where((c) => c == 'loadInterstitialAd').length, 1);
      expect(consent.isPrivacyOptionsRequired, true);
      expect(consent.isBusy, false);
    },
  );

  test(
    'privacy form refreshes permission and repeated taps share one form',
    () async {
      await consent.requestConsent();
      final form = Completer<void>();
      respond = (call) async {
        if (call.method == 'UserMessagingPlatform#showPrivacyOptionsForm') {
          await form.future;
        }
        if (call.method == 'ConsentInformation#canRequestAds') return allowed;
        if (call.method ==
            'ConsentInformation#getPrivacyOptionsRequirementStatus') {
          return 1;
        }
        return null;
      };
      final first = consent.showPrivacyOptionsForm();
      final second = consent.showPrivacyOptionsForm();
      expect(identical(first, second), true);
      expect(consent.isConsentSafe, false);
      expect(consent.isBusy, true);
      final permission = consent.requestConsent();
      allowed = false;
      form.complete();
      expect(await first, true);
      expect(await permission, false);
      expect(consent.isConsentSafe, false);
      expect(consent.isBusy, false);
      expect(
        calls
            .where(
              (c) => c.method == 'UserMessagingPlatform#showPrivacyOptionsForm',
            )
            .length,
        1,
      );
    },
  );

  test(
    'privacy action during initial consent waits then opens privacy form',
    () async {
      final form = Completer<void>();
      final opened = Completer<void>();
      respond = (call) async {
        if (call.method ==
            'UserMessagingPlatform#loadAndShowConsentFormIfRequired') {
          opened.complete();
          await form.future;
        }
        if (call.method == 'ConsentInformation#canRequestAds') return true;
        if (call.method ==
            'ConsentInformation#getPrivacyOptionsRequirementStatus') {
          return 1;
        }
        return null;
      };
      final initial = consent.requestConsent();
      await opened.future;
      final privacy = consent.showPrivacyOptionsForm();
      final anotherPrivacyTap = consent.showPrivacyOptionsForm();
      expect(
        calls.any(
          (c) => c.method == 'UserMessagingPlatform#showPrivacyOptionsForm',
        ),
        false,
      );
      form.complete();
      expect(await initial, true);
      expect(await privacy, true);
      expect(await anotherPrivacyTap, true);
      expect(
        calls
            .where(
              (c) => c.method == 'UserMessagingPlatform#showPrivacyOptionsForm',
            )
            .length,
        1,
      );
    },
  );

  test(
    'no privacy form request when UMP does not require an entry point',
    () async {
      privacyRequired = false;
      await consent.requestConsent();
      expect(await consent.showPrivacyOptionsForm(), false);
      expect(
        calls.any(
          (c) => c.method == 'UserMessagingPlatform#showPrivacyOptionsForm',
        ),
        false,
      );
    },
  );

  test(
    'UMP update failure uses official permission and exposes the error',
    () async {
      respond = (call) async {
        if (call.method == 'ConsentInformation#requestConsentInfoUpdate') {
          throw PlatformException(code: '2', message: 'offline');
        }
        if (call.method == 'ConsentInformation#canRequestAds') return true;
        if (call.method ==
            'ConsentInformation#getPrivacyOptionsRequirementStatus') {
          return 1;
        }
        return null;
      };
      expect(await consent.requestConsent(), true);
      expect(consent.lastError, 'offline');
      expect(consent.isBusy, false);
      expect(
        calls.any(
          (c) =>
              c.method ==
              'UserMessagingPlatform#loadAndShowConsentFormIfRequired',
        ),
        false,
      );
    },
  );

  test('privacy form failure returns false and refreshes permission', () async {
    await consent.requestConsent();
    respond = (call) async {
      if (call.method == 'UserMessagingPlatform#showPrivacyOptionsForm') {
        throw PlatformException(code: '3', message: 'form unavailable');
      }
      if (call.method == 'ConsentInformation#canRequestAds') return false;
      if (call.method ==
          'ConsentInformation#getPrivacyOptionsRequirementStatus') {
        return 1;
      }
      return null;
    };
    expect(await consent.showPrivacyOptionsForm(), false);
    expect(consent.lastError, 'form unavailable');
    expect(consent.isConsentSafe, false);
    expect(consent.isBusy, false);
  });

  test('permission query failure never falls back to a consent enum', () async {
    respond = (call) async {
      if (call.method == 'ConsentInformation#canRequestAds') {
        throw PlatformException(code: '2', message: 'unavailable');
      }
      return 0;
    };
    expect(await consent.canRequestAds(), false);
    expect(
      calls.any((c) => c.method == 'ConsentInformation#getConsentStatus'),
      false,
    );
  });

  test('reset invalidates delayed consent callbacks', () async {
    final update = Completer<void>();
    final started = Completer<void>();
    respond = (call) async {
      if (call.method == 'ConsentInformation#requestConsentInfoUpdate') {
        started.complete();
        await update.future;
      }
      if (call.method == 'ConsentInformation#canRequestAds') return true;
      return null;
    };
    final pending = consent.requestConsent();
    await started.future;
    await consent.reset();
    update.complete();
    expect(await pending, false);
    expect(consent.isConsentSafe, false);
    expect(
      calls.any(
        (c) =>
            c.method ==
            'UserMessagingPlatform#loadAndShowConsentFormIfRequired',
      ),
      false,
    );
  });

  test('privacy form does not overlap a fullscreen ad', () async {
    await consent.requestConsent();
    final token = AdOrchestrator.instance.acquireToken('interstitial');
    expect(await consent.showPrivacyOptionsForm(), false);
    expect(
      calls.any(
        (c) => c.method == 'UserMessagingPlatform#showPrivacyOptionsForm',
      ),
      false,
    );
    AdOrchestrator.instance.releaseWithToken(token!);
  });

  testWidgets('privacy button follows requirement and disables while open', (
    tester,
  ) async {
    privacyRequired = false;
    await consent.requestConsent();
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyConsentButton(
            child: const Text('Privacy settings'),
            onCompleted: (_) => completed++,
          ),
        ),
      ),
    );
    expect(find.text('Privacy settings'), findsNothing);
    privacyRequired = true;
    await consent.canRequestAds();
    await tester.pump();
    expect(find.text('Privacy settings'), findsOneWidget);
    final form = Completer<void>();
    respond = (call) async {
      if (call.method == 'UserMessagingPlatform#showPrivacyOptionsForm') {
        await form.future;
      }
      if (call.method == 'ConsentInformation#canRequestAds') return true;
      if (call.method ==
          'ConsentInformation#getPrivacyOptionsRequirementStatus') {
        return 1;
      }
      return null;
    };
    await tester.tap(find.text('Privacy settings'));
    await tester.pump();
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, null);
    form.complete();
    await tester.pump();
    expect(completed, 1);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
