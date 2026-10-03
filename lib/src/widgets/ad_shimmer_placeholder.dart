import 'package:flutter/material.dart';

/// Layout variants for [AdShimmerPlaceholder].
enum AdShimmerVariant {
  /// Standard banner (320x50 or 100% width x 50).
  banner,

  /// Large banner / medium rectangle (300x250).
  mediumRectangle,

  /// Small native card with icon, title, and button.
  nativeSmall,

  /// Medium horizontal native card (120x120 media + right text & CTA).
  nativeMedium,

  /// Big vertical native card with media container on top, icon, text, and button (280dp).
  nativeBig,

  /// Fullscreen immersive native card with media container and bottom details.
  nativeFullScreen,
}

/// A lightweight, zero-dependency shimmer placeholder widget designed to
/// eliminate Cumulative Layout Shift (CLS) while ads are loading.
class AdShimmerPlaceholder extends StatefulWidget {
  /// The height of the shimmer placeholder.
  final double? height;

  /// The width of the shimmer placeholder.
  final double? width;

  /// The layout style preset.
  final AdShimmerVariant variant;

  /// Base background color.
  final Color? baseColor;

  /// Shimmer highlight color.
  final Color? highlightColor;

  /// Border radius of the container.
  final BorderRadius? borderRadius;

  /// Creates an [AdShimmerPlaceholder].
  const AdShimmerPlaceholder({
    super.key,
    this.height,
    this.width,
    this.variant = AdShimmerVariant.banner,
    this.baseColor,
    this.highlightColor,
    this.borderRadius,
  });

  @override
  State<AdShimmerPlaceholder> createState() => _AdShimmerPlaceholderState();
}

class _AdShimmerPlaceholderState extends State<AdShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final base = widget.baseColor ??
        (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final highlight = widget.highlightColor ??
        (isDark ? Colors.grey.shade700 : Colors.grey.shade100);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, highlight, base],
          stops: [
            (_controller.value - 0.3).clamp(0.0, 1.0),
            _controller.value.clamp(0.0, 1.0),
            (_controller.value + 0.3).clamp(0.0, 1.0),
          ],
        );

        switch (widget.variant) {
          case AdShimmerVariant.banner:
            return _buildBannerPlaceholder(gradient);
          case AdShimmerVariant.mediumRectangle:
            return _buildMediumRectanglePlaceholder(gradient);
          case AdShimmerVariant.nativeSmall:
            return _buildNativeSmallPlaceholder(gradient, base);
          case AdShimmerVariant.nativeMedium:
            return _buildNativeMediumPlaceholder(gradient, base);
          case AdShimmerVariant.nativeBig:
            return _buildNativeBigPlaceholder(gradient, base);
          case AdShimmerVariant.nativeFullScreen:
            return _buildNativeFullScreenPlaceholder(gradient, base);
        }
      },
    );
  }

  Widget _buildNativeFullScreenPlaceholder(Gradient gradient, Color bg) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fullscreen media shimmer
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: gradient),
          ),
          // Top header badge
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              width: 32,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
          ),
          // Bottom content (Icon + Headline + CTA)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 16,
                            width: 160,
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 12,
                            width: 220,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPlaceholder(Gradient gradient) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 50.0,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(4.0),
      ),
    );
  }

  Widget _buildMediumRectanglePlaceholder(Gradient gradient) {
    return Container(
      width: widget.width ?? 300.0,
      height: widget.height ?? 250.0,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8.0),
      ),
    );
  }

  Widget _buildNativeSmallPlaceholder(Gradient gradient, Color bg) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 90.0,
      padding: const EdgeInsets.all(5.0),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.3),
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8.0),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 50x50 Ad App Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(6.0),
            ),
          ),
          const SizedBox(width: 8),
          // Headline + Badge + Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 18,
                      decoration: BoxDecoration(
                        color: bg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 15,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 90x40 CTA Button
          Container(
            width: 90,
            height: 40,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(6.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeMediumPlaceholder(Gradient gradient, Color bg) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 120.0,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.3),
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8.0),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left 120x120 media view container (fitted in height)
          Container(
            width: 104,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(6.0),
            ),
          ),
          const SizedBox(width: 8),
          // Right content (Header, Advertiser, Body, CTA)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 16,
                      decoration: BoxDecoration(
                        color: bg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  width: 90,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeBigPlaceholder(Gradient gradient, Color bg) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 280.0,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.3),
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12.0),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 44,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ],
      ),
    );
  }
}
