import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  group('AdMobConfig', () {
    test('resolves configured ad units explicitly from code', () {
      const config = AdMobConfig(
        android: AdPlatformConfig(
          interstitial: 'android-interstitial-id',
          rewarded: 'android-rewarded-id',
          appOpen: 'android-appopen-id',
          banner: 'android-banner-id',
          native: 'android-native-id',
        ),
      );

      // On macOS/tests, Platform.isIOS is false, resolves android config
      expect(config.interstitialId, 'android-interstitial-id');
      expect(config.rewardedId, 'android-rewarded-id');
      expect(config.appOpenId, 'android-appopen-id');
      expect(config.bannerId, 'android-banner-id');
      expect(config.nativeId, 'android-native-id');
    });

    test('returns null when ad unit is not configured', () {
      const config = AdMobConfig();

      expect(config.interstitialId, isNull);
      expect(config.rewardedId, isNull);
      expect(config.appOpenId, isNull);
      expect(config.bannerId, isNull);
      expect(config.nativeId, isNull);
    });

    test('copyWith updates specified fields cleanly', () {
      const config = AdMobConfig(isEntitled: false);
      final updated = config.copyWith(isEntitled: true);

      expect(config.isEntitled, isFalse);
      expect(updated.isEntitled, isTrue);
    });
  });
}
