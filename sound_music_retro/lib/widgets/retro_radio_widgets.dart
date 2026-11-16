import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_controller.dart';

/// Refined Retro Interactive FM Radio Deck at the top of the Home Screen
class RetroTopFmConsole extends StatelessWidget {
  final AudioController controller;

  const RetroTopFmConsole({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final activeFm = controller.activeFmStation;
    final isFmPlaying = controller.isFmMode && controller.isPlaying;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3E1818), Color(0xFF230E0E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFF4A1818),
          width: 2.2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1818),
            offset: Offset(4.w, 4.h),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Analog Dial Window + Speaker Grille + Power/Tune Controls
          Row(
            children: [
              // Vintage Brass/Cream Speaker Grille
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF3E8),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFD4A359),
                    width: 2.w,
                  ),
                ),
                child: CustomPaint(
                  painter: _VintageSpeakerPainter(isLive: isFmPlaying),
                ),
              ),
              SizedBox(width: 10.w),

              // Warm Cream Analog Frequency Dial Glass
              Expanded(
                child: Container(
                  height: 48.w,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF9EE), Color(0xFFF3E2C7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFFD4A359),
                      width: 1.8.w,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            activeFm != null
                                ? activeFm.name
                                : 'LIVE FM TUNER',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: const Color(0xFF4A1818),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 5.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: controller.isFmLoading
                                  ? const Color(0xFFD4A359)
                                  : isFmPlaying
                                      ? const Color(0xFFD32F2F)
                                      : const Color(0xFF8D6E63),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              controller.isFmLoading
                                  ? 'TUNING'
                                  : isFmPlaying
                                      ? 'ON AIR'
                                      : 'FM',
                              style: GoogleFonts.montserrat(
                                fontSize: 7.5.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 18.h,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _AnalogDialScalePainter(
                            stationIndex: activeFm == null
                                ? 1
                                : controller.fmStations.indexOf(activeFm),
                            totalStations: controller.fmStations.length,
                            isLive: isFmPlaying,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 10.w),

              // Quick Play / Stop FM Button
              GestureDetector(
                onTap: () {
                  if (activeFm == null) {
                    controller.playFmStation(controller.fmStations.first);
                  } else {
                    controller.togglePlayPause();
                  }
                },
                child: Container(
                  width: 46.w,
                  height: 46.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isFmPlaying
                          ? [const Color(0xFFFF1744), const Color(0xFFB71C1C)]
                          : [const Color(0xFFFFFBF4), const Color(0xFFF3E2C7)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4A359),
                      width: 2.w,
                    ),
                  ),
                  child: controller.isFmLoading
                      ? Padding(
                          padding: EdgeInsets.all(12.r),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFFC62828),
                          ),
                        )
                      : Icon(
                          isFmPlaying
                              ? Icons.pause_rounded
                              : Icons.radio_rounded,
                          color: isFmPlaying
                              ? Colors.white
                              : const Color(0xFFB71C1C),
                          size: 22.sp,
                        ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // Horizontal Playable FM Station Preset Pills
          SizedBox(
            height: 30.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.fmStations.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final station = controller.fmStations[index];
                final isSelected = activeFm?.id == station.id;

                return GestureDetector(
                  onTap: () => controller.playFmStation(station),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFFFAF3E8).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFFCDD2)
                            : const Color(0xFFD4A359).withOpacity(0.5),
                        width: 1.3.w,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          station.frequency,
                          style: GoogleFonts.montserrat(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? const Color(0xFFFFEB3B)
                                : const Color(0xFFD4A359),
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          station.name,
                          style: GoogleFonts.montserrat(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (controller.fmErrorMessage != null) ...[
            SizedBox(height: 6.h),
            Text(
              controller.fmErrorMessage!,
              style: GoogleFonts.montserrat(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFCDD2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VintageSpeakerPainter extends CustomPainter {
  final bool isLive;

  _VintageSpeakerPainter({required this.isLive});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF4A1818).withOpacity(0.75)
      ..style = PaintingStyle.fill;

    const rows = 5;
    const cols = 5;
    final dx = size.width / (cols + 1);
    final dy = size.height / (rows + 1);

    for (int r = 1; r <= rows; r++) {
      for (int c = 1; c <= cols; c++) {
        canvas.drawCircle(Offset(c * dx, r * dy), 1.5, dotPaint);
      }
    }

    final emblemPaint = Paint()
      ..color = isLive ? const Color(0xFFD32F2F) : const Color(0xFFD4A359)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 6, emblemPaint);
  }

  @override
  bool shouldRepaint(covariant _VintageSpeakerPainter oldDelegate) =>
      oldDelegate.isLive != isLive;
}

class _AnalogDialScalePainter extends CustomPainter {
  final int stationIndex;
  final int totalStations;
  final bool isLive;

  _AnalogDialScalePainter({
    required this.stationIndex,
    required this.totalStations,
    required this.isLive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = const Color(0xFF4A1818).withOpacity(0.5)
      ..strokeWidth = 1.3;

    const totalTicks = 28;
    final step = size.width / totalTicks;

    for (int i = 0; i <= totalTicks; i++) {
      final x = i * step;
      final isMajor = i % 4 == 0;
      canvas.drawLine(
        Offset(x, isMajor ? 2 : 6),
        Offset(x, size.height - 2),
        tickPaint,
      );
    }

    final ratio = totalStations <= 1
        ? 0.5
        : (stationIndex.clamp(0, totalStations - 1) + 0.5) / totalStations;
    final needleX = size.width * ratio;

    final needlePaint = Paint()
      ..color = isLive ? const Color(0xFFD32F2F) : const Color(0xFF8E0000)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(needleX, 0),
      Offset(needleX, size.height),
      needlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalogDialScalePainter oldDelegate) =>
      oldDelegate.stationIndex != stationIndex || oldDelegate.isLive != isLive;
}

/// Refined Retro Transistor Radio Empty State Illustration
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
            width: 156.w,
            height: 98.h,
            child: CustomPaint(
              painter: _RetroBoomboxPainter(),
            ),
          ),
          if (message.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Text(
              message,
              style: GoogleFonts.montserrat(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: const Color(0xFF4A1818),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RetroBoomboxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFF4A1818)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final redFill = Paint()
      ..color = const Color(0xFFC62828)
      ..style = PaintingStyle.fill;

    final creamFill = Paint()
      ..color = const Color(0xFFFFFBF4)
      ..style = PaintingStyle.fill;

    final brassFill = Paint()
      ..color = const Color(0xFFD4A359)
      ..style = PaintingStyle.fill;

    // Antenna
    canvas.drawLine(
      Offset(size.width * 0.25, 18),
      Offset(size.width * 0.78, 2),
      outline,
    );
    canvas.drawCircle(Offset(size.width * 0.78, 2), 3.5, brassFill);

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
    canvas.drawCircle(leftCenter, 18, creamFill);
    canvas.drawCircle(leftCenter, 18, outline);
    canvas.drawCircle(leftCenter, 7, brassFill);

    canvas.drawCircle(rightCenter, 18, creamFill);
    canvas.drawCircle(rightCenter, 18, outline);
    canvas.drawCircle(rightCenter, 7, brassFill);

    // Center Analog Dial Window
    final deckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.62),
        width: 30,
        height: 22,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(deckRect, creamFill);
    canvas.drawRRect(deckRect, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
