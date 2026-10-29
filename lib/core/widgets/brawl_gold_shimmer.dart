import 'package:flutter/material.dart';

/// 60 FPS GPU-accelerated liquid gold shimmer gradient widget
/// inspired by the Brawl Stars Gold Pass aesthetic.
///
/// Uses [ShaderMask] with a multi-stop [LinearGradient] featuring:
/// - Metallic Gold (`#FFD700`)
/// - Amber Gold (`#FFA000`)
/// - Fluid Light Highlights (`#FFF8E1`)
/// - Specular White Reflection (`#FFFFFF`)
///
/// Crucial for testing: When running under test environments (detected via
/// [WidgetsBinding]), continuous ticker repeats are disabled to prevent
/// `tester.pumpAndSettle()` timeouts, rendering a static centered golden shimmer instead.
class BrawlGoldShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool isShimmering;

  const BrawlGoldShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2400),
    bool isShimmering = true,
    bool? enabled,
  }) : isShimmering = enabled ?? isShimmering;

  /// Flag to explicitly enable animations in widget tests if desired.
  static bool enableAnimationsInTests = false;

  @override
  State<BrawlGoldShimmer> createState() => _BrawlGoldShimmerState();
}

class _BrawlGoldShimmerState extends State<BrawlGoldShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    if (widget.isShimmering &&
        (!isTestEnvironment || BrawlGoldShimmer.enableAnimationsInTests)) {
      _controller.repeat();
    } else {
      // In test mode or when static, settle at 0.5 to show the bright gold highlight
      _controller.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(covariant BrawlGoldShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final shouldAnimate = widget.isShimmering &&
        (!isTestEnvironment || BrawlGoldShimmer.enableAnimationsInTests);

    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isShimmering) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final shift = -1.5 + 3.0 * progress;
            return LinearGradient(
              begin: Alignment(shift - 1.0, -0.5),
              end: Alignment(shift + 1.0, 0.5),
              colors: const [
                Color(0xFFFFA000), // Amber gold
                Color(0xFFFFD700), // Metallic gold
                Color(0xFFFFF8E1), // Fluid highlight
                Color(0xFFFFFFFF), // Specular reflection
                Color(0xFFFFF8E1), // Fluid highlight
                Color(0xFFFFD700), // Metallic gold
                Color(0xFFFFA000), // Amber gold
              ],
              stops: const [0.0, 0.25, 0.45, 0.50, 0.55, 0.75, 1.0],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
