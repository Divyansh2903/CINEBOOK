import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

//Frosted glassmorphism container used for panels, sheets and cards.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.card,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF161618).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? AppColors.surfaceVariant,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

//Outlined pill used for format / language / screen-type metadata.
class MetaChip extends StatelessWidget {
  const MetaChip(this.label, {super.key, this.icon, this.highlighted = false});
  final String label;
  final IconData? icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.primary : AppColors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.surfaceContainerHigh,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

//Gold star + score, the recurring rating motif.
class RatingBadge extends StatelessWidget {
  const RatingBadge(this.score, {super.key, this.size = 14});
  final double score;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: AppColors.primary, size: size + 2),
        const SizedBox(width: 2),
        Text(
          score.toStringAsFixed(1),
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: size,
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See All', style: TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

//Centered empty / error state with an optional retry.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.onSurfaceVariant, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

//A simple shimmering block for skeleton placeholders.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height, this.radius = 8});
  final double? width;
  final double? height;
  final double radius;
  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 - 2 * _c.value, 0),
            end: Alignment(1 - 2 * _c.value, 0),
            colors: const [
              Color(0xFF161618),
              Color(0xFF222224),
              Color(0xFF161618),
            ],
          ),
        ),
      ),
    );
  }
}

//Top-aligned scrim so foreground content stays legible over backdrops.
BoxDecoration topScrim() => const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [AppColors.background, Color(0x99121414), Colors.transparent],
  ),
);

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        closeIconColor: AppColors.onSurfaceVariant,
      ),
    );
}
