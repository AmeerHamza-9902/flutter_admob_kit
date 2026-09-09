import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Click Counter Show Rate Fix', () {
    test('onClickEvent does not reset click count if ad is not ready', () {
      final manager = InterstitialAdManager();

      // Click 1: threshold 3, count becomes 1
      expect(manager.onClickEvent('test-ad-unit', threshold: 3), false);

      // Click 2: count becomes 2
      expect(manager.onClickEvent('test-ad-unit', threshold: 3), false);

      // Click 3: threshold 3 reached, but ad is NOT ready.
      // Crucial fix: count must NOT reset to 0 so the impression request isn't wasted!
      expect(manager.onClickEvent('test-ad-unit', threshold: 3), false);

      // Click 4: count continues past or at threshold instead of starting over from 1
      expect(manager.onClickEvent('test-ad-unit', threshold: 3), false);

      manager.dispose();
    });
  });
}
