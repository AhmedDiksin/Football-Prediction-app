import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PointGem extends StatelessWidget {
  const PointGem({super.key, this.size = 16, this.color = AppColors.cyan});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.52,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
      ),
    );
  }
}
