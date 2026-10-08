import 'package:flutter/material.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both official template sizes default to a white background', () {
    const style = NativeAdStyle();
    expect(style.cornerRadius, 10);
    expect(style.toNativeOptions()['cornerRadius'], 10);
    for (final template in NativeTemplate.values) {
      expect(
        style.toGoogleTemplateStyle(template).mainBackgroundColor,
        Colors.white,
      );
    }
    expect(
      const NativeAdStyle(
        backgroundColor: null,
      ).toGoogleTemplateStyle(NativeTemplate.bigNative).mainBackgroundColor,
      Colors.white,
    );
  });

  test('custom colors and radius reach Android and official templates', () {
    const style = NativeAdStyle(
      backgroundColor: Colors.black,
      cornerRadius: 16,
      callToActionColor: Colors.green,
      callToActionTextColor: Colors.yellow,
      primaryTextColor: Colors.white,
      secondaryTextColor: Colors.grey,
    );
    final options = style.toNativeOptions();
    expect(options['backgroundColor'], Colors.black.toARGB32());
    expect(options['cornerRadius'], 16);
    expect(options['callToActionColor'], Colors.green.toARGB32());
    expect(options['callToActionTextColor'], Colors.yellow.toARGB32());
    expect(options['primaryTextColor'], Colors.white.toARGB32());
    expect(options['secondaryTextColor'], Colors.grey.toARGB32());
    expect(
      style.toGoogleTemplateStyle(NativeTemplate.bigNative).mainBackgroundColor,
      Colors.black,
    );
    expect(
      const NativeAdStyle()
          .copyWith(backgroundColor: Colors.black)
          .backgroundColor,
      Colors.black,
    );
  });

  test('invalid or excessive radius is safe on every rendering path', () {
    for (final (input, expected) in [
      (double.nan, 10.0),
      (double.infinity, 10.0),
      (double.negativeInfinity, 10.0),
      (-5.0, 0.0),
      (2000.0, 1000.0),
    ]) {
      final style = NativeAdStyle(cornerRadius: input);
      expect(style.effectiveCornerRadius, expected);
      expect(style.toNativeOptions()['cornerRadius'], expected);
      expect(
        style.toGoogleTemplateStyle(NativeTemplate.small).cornerRadius,
        expected,
      );
    }
    expect(
      const NativeAdStyle(cornerRadius: double.nan),
      const NativeAdStyle(cornerRadius: double.infinity),
    );
    expect(
      const NativeAdStyle(cornerRadius: -5).hashCode,
      const NativeAdStyle(cornerRadius: 0).hashCode,
    );
  });
}
