import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  group('AdMobConfig', () {
    test('resolves configured production ad units', () {
      const config = AdMobConfig(
        android: AdPlatformConfig(
          interstitial: 'android-interstitial-prod',
          rewarded: 'android-rewarded-prod',
          appOpen: 'android-appopen-prod',
          banner: 'android-banner-prod',
          native: 'android-native-prod',
        ),
        testMode: false,
      );

      // On macOS/tests, Platform.isIOS is false, resolves android config
      expect(config.interstitialId, 'android-interstitial-prod');
      expect(config.rewardedId, 'android-rewarded-prod');
      expect(config.appOpenId, 'android-appopen-prod');
      expect(config.bannerId, 'android-banner-prod');
      expect(config.nativeId, 'android-native-prod');
    });

    test('resolves official Google test ad units when testMode is true', () {
      const config = AdMobConfig(
        android: AdPlatformConfig(
          interstitial: 'custom-id',
        ),
        testMode: true,
      );

      // Automatically uses official Google test IDs instead of custom production IDs
      expect(config.interstitialId, AdMobTestIds.androidInterstitial);
      expect(config.rewardedId, AdMobTestIds.androidRewarded);
      expect(config.appOpenId, AdMobTestIds.androidAppOpen);
      expect(config.bannerId, AdMobTestIds.androidBanner);
      expect(config.nativeId, AdMobTestIds.androidNative);
    });

    test('copyWith updates specified fields cleanly', () {
      const config = AdMobConfig(testMode: false, isEntitled: false);
      final updated = config.copyWith(testMode: true, isEntitled: true);

      expect(config.testMode, isFalse);
      expect(config.isEntitled, isFalse);
      expect(updated.testMode, isTrue);
      expect(updated.isEntitled, isTrue);
    });
  });
}
