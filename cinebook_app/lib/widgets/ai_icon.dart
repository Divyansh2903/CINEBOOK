import 'package:flutter/material.dart';

import '../core/theme.dart';

//The CineBook AI sparkle mark. The asset is a silhouette on transparency,
//so it tints cleanly to any color via srcIn.
class AiIcon extends StatelessWidget {
  const AiIcon({super.key, this.size = 20, this.color = AppColors.primary});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/ai_icon.png',
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
    );
  }
}
