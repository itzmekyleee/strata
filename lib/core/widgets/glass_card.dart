import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/strata_palette.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.borderColor,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: StrataPalette.surfaceHigh.withValues(alpha: .72),
        border: Border.all(color: borderColor ?? StrataPalette.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .38 : .12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .18 : .05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

extension EntranceAnimations on Widget {
  Widget entrance({required int index, int baseMs = 60}) =>
      animate(delay: Duration(milliseconds: baseMs * index))
          .fadeIn(duration: 300.ms)
          .slideY(
            begin: .1,
            end: 0,
            curve: Curves.easeOutQuint,
            duration: 300.ms,
          );
}