import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RetroTactileButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final double? width;
  final double? height;
  final bool isPrimaryRed;
  final bool isCircular;

  const RetroTactileButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onDoubleTap,
    this.width,
    this.height,
    this.isPrimaryRed = false,
    this.isCircular = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = isCircular ? BoxShape.circle : BoxShape.rectangle;
    final radius = isCircular ? null : BorderRadius.circular(14.r);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: radius,
          gradient: isPrimaryRed
              ? const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFBF4), Color(0xFFF6E8D5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: const Color(0xFF4A1818),
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A1818),
              offset: Offset(3.w, 3.h),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
