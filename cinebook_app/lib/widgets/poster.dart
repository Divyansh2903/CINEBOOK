import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

//A poster/backdrop image with shimmer placeholder and a graceful fallback.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.icon = Icons.movie_outlined,
  });

  final String? url;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => const _Shimmer(),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => Container(
    color: AppColors.surfaceContainerHigh,
    alignment: Alignment.center,
    child: Icon(icon, color: AppColors.outline, size: 40),
  );
}

class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
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
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
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
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
