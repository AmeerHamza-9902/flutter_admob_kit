import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Pre-built template sizes for Native Ads.
enum NativeTemplate {
  /// Small compact native card (icon + headline + CTA button). Ideal for list rows (height ~90dp).
  small,

  /// Horizontal 120dp card with media, text and CTA.
  mediumNative,

  /// Large media/header/CTA card used for prominent placements such as splash.
  bigNative,

  /// Compatibility alias for the former large `medium` template.
  @Deprecated('Use NativeTemplate.bigNative instead.')
  medium,
}

/// Custom visual styling for Native Ad templates.
///
/// Allows developers to fully customize the appearance of Native Ads:
/// - Background color
/// - CTA button background & text colors
/// - Headline & body text colors
/// - Corner radius
class NativeAdStyle {
  const NativeAdStyle({
    this.backgroundColor = Colors.white,
    this.cornerRadius = 8.0,
    this.callToActionColor,
    this.callToActionTextColor = Colors.white,
    this.primaryTextColor,
    this.secondaryTextColor,
  });

  /// Main background color of the native ad card. Defaults to white.
  /// Passing null also resolves to white.
  final Color? backgroundColor;

  /// Corner radius of the ad container (and official-template CTA).
  /// Corner radius used by bundled Android cards and CTAs.
  final double cornerRadius;

  /// Background color of the Call To Action button.
  final Color? callToActionColor;

  /// Text color inside the Call To Action button. Defaults to [Colors.white].
  final Color callToActionTextColor;

  /// Text color for the headline/title (e.g. `#0E1A14`).
  final Color? primaryTextColor;

  /// Text color for the body/description/advertiser (e.g. `#55655D`).
  final Color? secondaryTextColor;

  /// Converts this style to the official [NativeTemplateStyle] used by Google Mobile Ads.
  NativeTemplateStyle toGoogleTemplateStyle(NativeTemplate template) {
    final isSmall =
        template == NativeTemplate.small ||
        template == NativeTemplate.mediumNative;
    return NativeTemplateStyle(
      templateType: isSmall ? TemplateType.small : TemplateType.medium,
      mainBackgroundColor: backgroundColor ?? Colors.white,
      cornerRadius: cornerRadius,
      callToActionTextStyle:
          callToActionColor != null || callToActionTextColor != Colors.white
          ? NativeTemplateTextStyle(
              backgroundColor: callToActionColor,
              textColor: callToActionTextColor,
              style: NativeTemplateFontStyle.bold,
              size: isSmall ? 14.0 : 16.0,
            )
          : null,
      primaryTextStyle: primaryTextColor != null
          ? NativeTemplateTextStyle(
              textColor: primaryTextColor,
              style: NativeTemplateFontStyle.bold,
              size: isSmall ? 15.0 : 16.0,
            )
          : null,
      secondaryTextStyle: secondaryTextColor != null
          ? NativeTemplateTextStyle(
              textColor: secondaryTextColor,
              style: NativeTemplateFontStyle.normal,
              size: isSmall ? 12.0 : 14.0,
            )
          : null,
    );
  }

  /// Styling passed to the bundled Android medium layout.
  Map<String, Object> toNativeOptions() => {
    'backgroundColor': (backgroundColor ?? Colors.white).toARGB32(),
    'cornerRadius': cornerRadius,
    'callToActionColor': (callToActionColor ?? const Color(0xFF2563EB))
        .toARGB32(),
    'callToActionTextColor': callToActionTextColor.toARGB32(),
    'primaryTextColor': (primaryTextColor ?? const Color(0xFF111827))
        .toARGB32(),
    'secondaryTextColor': (secondaryTextColor ?? const Color(0xFF4B5563))
        .toARGB32(),
  };

  @override
  bool operator ==(Object other) =>
      other is NativeAdStyle &&
      backgroundColor == other.backgroundColor &&
      cornerRadius == other.cornerRadius &&
      callToActionColor == other.callToActionColor &&
      callToActionTextColor == other.callToActionTextColor &&
      primaryTextColor == other.primaryTextColor &&
      secondaryTextColor == other.secondaryTextColor;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    cornerRadius,
    callToActionColor,
    callToActionTextColor,
    primaryTextColor,
    secondaryTextColor,
  );

  /// Creates a copy of this style with modified properties.
  NativeAdStyle copyWith({
    Color? backgroundColor,
    double? cornerRadius,
    Color? callToActionColor,
    Color? callToActionTextColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  }) {
    return NativeAdStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      callToActionColor: callToActionColor ?? this.callToActionColor,
      callToActionTextColor:
          callToActionTextColor ?? this.callToActionTextColor,
      primaryTextColor: primaryTextColor ?? this.primaryTextColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
    );
  }
}
