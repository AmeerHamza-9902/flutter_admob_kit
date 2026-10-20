import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('upcoming placements share requests and respect consent', (
    tester,
  ) async {
    AdMobKit.resetForTesting();
    final loads = <String>[];
    var allowed = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_mobile_ads/ump'),
      (call) async =>
          call.method == 'ConsentInformation#canRequestAds' ? allowed : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_admob_kit/native_templates'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      MethodChannel(
        'plugins.flutter.io/google_mobile_ads',
        StandardMethodCodec(AdMessageCodec()),
      ),
      (call) async {
        if (call.method == 'MobileAds#initialize') {
          return InitializationStatus({});
        }
        if (call.method == 'loadNativeAd' || call.method == 'loadBannerAd') {
          loads.add(call.method);
        }
        return null;
      },
    );
    const placements = [
      InlinePlacement.native(
        adUnitId: 'language',
        template: NativeTemplate.mediaCtaNative,
      ),
      InlinePlacement.banner(
        adUnitId: 'onboarding',
        size: AdSize.mediumRectangle,
      ),
    ];
    await AdMobKit.initialize(
      config: const AdMobConfig(enableUmpConsent: false),
    );
    AdMobKit.prepareInlinePlacements(placements);
    await tester.pump();
    expect(loads, isEmpty);
    allowed = true;
    await AdMobKit.consent.canRequestAds();
    AdMobKit.prepareInlinePlacements(placements);
    AdMobKit.prepareInlinePlacements(placements);
    await tester.pump();
    expect(loads.where((m) => m == 'loadNativeAd'), hasLength(1));
    expect(loads.where((m) => m == 'loadBannerAd'), hasLength(1));
    AdMobKit.updateConfig(
      const AdMobConfig(
        enableUmpConsent: false,
        android: AdPlatformConfig(interstitial: 'click'),
      ),
    );
    AdMobKit.prepareInlinePlacements(placements);
    await tester.pump();
    expect(loads, hasLength(2));
    AdMobKit.resetForTesting();
    await tester.pump();
  });
}
