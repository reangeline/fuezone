import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';

class PressableCard extends StatefulWidget {
  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 16.0,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _handleTapUp(TapUpDetails _)     => setState(() => _pressed = false);
  void _handleTapCancel()               => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ??
        Theme.of(context).colorScheme.surface.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 1.0
                  : 0.9,
            );

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: widget.onTap != null ? _handleTapDown : null,
      onTapUp: widget.onTap != null ? _handleTapUp : null,
      onTapCancel: widget.onTap != null ? _handleTapCancel : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppAnimations.durationFast,
        curve: AppAnimations.curveSpring,
        child: AnimatedContainer(
          duration: AppAnimations.durationFast,
          curve: AppAnimations.curveDefault,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _pressed
                ? null
                : [
                    BoxShadow(
                      color: AppColors.background.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
