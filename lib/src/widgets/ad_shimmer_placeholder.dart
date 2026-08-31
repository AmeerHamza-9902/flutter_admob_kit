import 'package:flutter/material.dart';

/// Layout variants for [AdShimmerPlaceholder].
enum AdShimmerVariant {
  /// Standard banner (320x50 or 100% width x 50).
  banner,

  /// Large banner / medium rectangle (300x250).
  mediumRectangle,

  /// Small native card with icon, title, and button.
  nativeSmall,

  /// Medium/Large native card with media container, icon, text, and button.
  nativeMedium,
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
        }
      },
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
      height: widget.height ?? 100.0,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.3),
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12.0),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 70,
            height: 32,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeMediumPlaceholder(Gradient gradient, Color bg) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 300.0,
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
                width: 40,
                height: 40,
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
                      height: 12,
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
              const SizedBox(width: 10),
              Container(
                width: 80,
                height: 36,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
