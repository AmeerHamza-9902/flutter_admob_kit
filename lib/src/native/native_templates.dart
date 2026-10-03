import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Pre-built template sizes for Native Ads.
enum NativeTemplate {
  /// Small compact native card (icon + headline + CTA button). Ideal for feeds (height ~90).
  small,

  /// Medium / Big native card (media view + icon + headline + body + CTA button).
  /// Matches standard 280-320dp native layouts.
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
    this.backgroundColor,
    this.cornerRadius = 8.0,
    this.callToActionColor,
    this.callToActionTextColor = Colors.white,
    this.primaryTextColor,
    this.secondaryTextColor,
  });

  /// Main background color of the native ad card.
  final Color? backgroundColor;

  /// Corner radius of the ad container and CTA button.
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
    return NativeTemplateStyle(
      templateType: template == NativeTemplate.small
          ? TemplateType.small
          : TemplateType.medium,
      mainBackgroundColor: backgroundColor,
      cornerRadius: cornerRadius,
      callToActionTextStyle: callToActionColor != null || callToActionTextColor != Colors.white
          ? NativeTemplateTextStyle(
              backgroundColor: callToActionColor,
              textColor: callToActionTextColor,
              style: NativeTemplateFontStyle.bold,
              size: 15.0,
            )
          : null,
      primaryTextStyle: primaryTextColor != null
          ? NativeTemplateTextStyle(
              textColor: primaryTextColor,
              style: NativeTemplateFontStyle.bold,
              size: 14.0,
            )
          : null,
      secondaryTextStyle: secondaryTextColor != null
          ? NativeTemplateTextStyle(
              textColor: secondaryTextColor,
              style: NativeTemplateFontStyle.normal,
              size: 12.0,
            )
          : null,
    );
  }

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
