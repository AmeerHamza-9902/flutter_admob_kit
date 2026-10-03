import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Pre-built template sizes for Native Ads.
enum NativeTemplate {
  /// Small compact native card (icon + headline + CTA button). Ideal for feeds.
  small,

  /// Medium native card (media view + icon + headline + body + CTA button). Ideal for content streams.
  medium,
}

/// Custom visual styling for Native Ad templates.
class NativeAdStyle {
  const NativeAdStyle({
    this.backgroundColor,
    this.cornerRadius = 8.0,
    this.callToActionColor,
    this.primaryTextColor,
    this.secondaryTextColor,
  });

  /// Main background color of the native ad card.
  final Color? backgroundColor;

  /// Corner radius of the ad container and CTA button.
  final double cornerRadius;

  /// Background color of the Call To Action button.
  final Color? callToActionColor;

  /// Text color for the headline/title.
  final Color? primaryTextColor;

  /// Text color for the body description.
  final Color? secondaryTextColor;

  /// Converts this style to the official [NativeTemplateStyle] used by Google Mobile Ads.
  NativeTemplateStyle toGoogleTemplateStyle(NativeTemplate template) {
    return NativeTemplateStyle(
      templateType: template == NativeTemplate.small
          ? TemplateType.small
          : TemplateType.medium,
      mainBackgroundColor: backgroundColor,
      cornerRadius: cornerRadius,
      callToActionTextStyle: callToActionColor != null
          ? NativeTemplateTextStyle(
              backgroundColor: callToActionColor,
              textColor: Colors.white,
              style: NativeTemplateFontStyle.bold,
              size: 14.0,
            )
          : null,
      primaryTextStyle: primaryTextColor != null
          ? NativeTemplateTextStyle(
              textColor: primaryTextColor,
              style: NativeTemplateFontStyle.bold,
              size: 16.0,
            )
          : null,
      secondaryTextStyle: secondaryTextColor != null
          ? NativeTemplateTextStyle(
              textColor: secondaryTextColor,
              style: NativeTemplateFontStyle.normal,
              size: 14.0,
            )
          : null,
    );
  }
}
