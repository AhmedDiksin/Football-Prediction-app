import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue, AppColors.cyan, AppColors.mint],
        ),
      ),
      child: Center(
        child: Transform.rotate(
          angle: -0.15,
          child: Container(
            width: size * 0.42,
            height: size * 0.22,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(size * 0.06),
            ),
          ),
        ),
      ),
    );
  }
}
