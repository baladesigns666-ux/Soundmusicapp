import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RetroTactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final bool isPrimaryRed;
  final bool isCircular;

  const RetroTactileButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.isPrimaryRed = false,
    this.isCircular = false,
  });

  @override
  State<RetroTactileButton> createState() => _RetroTactileButtonState();
}

class _RetroTactileButtonState extends State<RetroTactileButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final shape = widget.isCircular ? BoxShape.circle : BoxShape.rectangle;
    final radius = widget.isCircular ? null : BorderRadius.circular(14.r);

    // No onDoubleTap here so single taps trigger immediately with zero 300ms gesture delay!
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 65),
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(
          _isPressed ? 1.5.w : 0,
          _isPressed ? 1.5.h : 0,
          0,
        ),
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: radius,
          gradient: widget.isPrimaryRed
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
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF4A1818),
                    offset: Offset(3.w, 3.h),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}
