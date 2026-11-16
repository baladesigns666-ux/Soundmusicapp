import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom Retro Analog FM Radio Frequency Scale & Signal Illustration
class RetroRadioTunerBanner extends StatelessWidget {
  final bool isPlaying;
  final double crossfadeSec;

  const RetroRadioTunerBanner({
    super.key,
    required this.isPlaying,
    required this.crossfadeSec,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFF8E0000),
          width: 2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E0000),
            offset: Offset(3.w, 3.h),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Retro Radio Speaker Grille Illustration
          SizedBox(
            width: 44.w,
            height: 36.h,
            child: CustomPaint(
              painter: _RadioSpeakerGrillePainter(isPlaying: isPlaying),
            ),
          ),
          SizedBox(width: 12.w),

          // Analog FM Frequency Dial Scale
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FM 88',
                      style: GoogleFonts.montserrat(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                    Text(
                      '98.5 MHz',
                      style: GoogleFonts.montserrat(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD32F2F),
                      ),
                    ),
                    Text(
                      '108 FM',
                      style: GoogleFonts.montserrat(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                SizedBox(
                  height: 16.h,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _RadioFrequencyDialPainter(isPlaying: isPlaying),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 10.w),

          // Stereo / Crossfade Status Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPlaying
                    ? [const Color(0xFFFF1744), const Color(0xFFB71C1C)]
                    : [const Color(0xFFFFFFFF), const Color(0xFFFFEBEE)],
              ),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: const Color(0xFF8E0000),
                width: 1.5.w,
              ),
            ),
            child: Column(
              children: [
                Text(
                  isPlaying ? 'ON AIR' : 'STEREO',
                  style: GoogleFonts.montserrat(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w800,
                    color: isPlaying ? Colors.white : const Color(0xFFB71C1C),
                  ),
                ),
                Text(
                  crossfadeSec > 0 ? 'XF ${crossfadeSec.toInt()}S' : 'HI-FI',
                  style: GoogleFonts.montserrat(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w600,
                    color: isPlaying
                        ? const Color(0xFFFFCDD2)
                        : const Color(0xFF616161),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioSpeakerGrillePainter extends CustomPainter {
  final bool isPlaying;

  _RadioSpeakerGrillePainter({required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFFB71C1C)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, bgPaint);

    // Draw vintage radio grille dots
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    const rows = 4;
    const cols = 5;
    final dx = size.width / (cols + 1);
    final dy = size.height / (rows + 1);

    for (int r = 1; r <= rows; r++) {
      for (int c = 1; c <= cols; c++) {
        canvas.drawCircle(Offset(c * dx, r * dy), 1.6, dotPaint);
      }
    }

    // Center vintage dial knob ring
    final ringPaint = Paint()
      ..color = isPlaying ? const Color(0xFFFFEB3B) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 8, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _RadioSpeakerGrillePainter oldDelegate) =>
      oldDelegate.isPlaying != isPlaying;
}

class _RadioFrequencyDialPainter extends CustomPainter {
  final bool isPlaying;

  _RadioFrequencyDialPainter({required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = const Color(0xFF8E0000).withOpacity(0.45)
      ..strokeWidth = 1.4;

    const totalTicks = 24;
    final step = size.width / totalTicks;

    for (int i = 0; i <= totalTicks; i++) {
      final x = i * step;
      final isMajor = i % 4 == 0;
      final top = isMajor ? 2.0 : 6.0;
      canvas.drawLine(Offset(x, top), Offset(x, size.height - 2), tickPaint);
    }

    // Red Tuning Needle Indicator
    final needleX = isPlaying ? size.width * 0.62 : size.width * 0.35;
    final needlePaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(needleX, 0),
      Offset(needleX, size.height),
      needlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadioFrequencyDialPainter oldDelegate) =>
      oldDelegate.isPlaying != isPlaying;
}

/// Retro Boombox / Transistor Radio Empty State Illustration
class RetroRadioIllustration extends StatelessWidget {
  final String message;

  const RetroRadioIllustration({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 150.w,
            height: 95.h,
            child: CustomPaint(
              painter: _RetroBoomboxPainter(),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            message,
            style: GoogleFonts.montserrat(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFFB71C1C),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetroBoomboxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFF8E0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final redFill = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    final whiteFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Antenna
    canvas.drawLine(
      Offset(size.width * 0.25, 18),
      Offset(size.width * 0.78, 2),
      outline,
    );
    canvas.drawCircle(Offset(size.width * 0.78, 2), 3.5, redFill);

    // Handle
    final handleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.22, 12, size.width * 0.56, 14),
      const Radius.circular(6),
    );
    canvas.drawRRect(handleRect, outline);

    // Radio Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 24, size.width - 16, size.height - 28),
      const Radius.circular(14),
    );
    canvas.drawRRect(bodyRect, redFill);
    canvas.drawRRect(bodyRect, outline);

    // Left & Right Speakers
    final leftCenter = Offset(size.width * 0.26, size.height * 0.62);
    final rightCenter = Offset(size.width * 0.74, size.height * 0.62);
    canvas.drawCircle(leftCenter, 18, whiteFill);
    canvas.drawCircle(leftCenter, 18, outline);
    canvas.drawCircle(leftCenter, 7, redFill);

    canvas.drawCircle(rightCenter, 18, whiteFill);
    canvas.drawCircle(rightCenter, 18, outline);
    canvas.drawCircle(rightCenter, 7, redFill);

    // Center Cassette Window
    final deckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.62),
        width: 30,
        height: 22,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(deckRect, whiteFill);
    canvas.drawRRect(deckRect, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
