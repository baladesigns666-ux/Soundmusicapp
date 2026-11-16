import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_controller.dart';

/// Refined Retro Interactive FM Radio Deck at the top of the Home Screen.
/// Automatically morphs between Full Console and Compact Mini-Tuner Bar when scrolling!
class RetroTopFmConsole extends StatefulWidget {
  final AudioController controller;
  final bool isCompact;

  const RetroTopFmConsole({
    super.key,
    required this.controller,
    this.isCompact = false,
  });

  @override
  State<RetroTopFmConsole> createState() => _RetroTopFmConsoleState();
}

class _RetroTopFmConsoleState extends State<RetroTopFmConsole> {
  double _lastTickMhz = 98.3;

  void _onDialDrag(double localDx, double dialWidth) {
    if (dialWidth <= 0) return;
    final ratio = (localDx / dialWidth).clamp(0.0, 1.0);
    final rawMhz = AudioController.minFmMhz +
        ratio * (AudioController.maxFmMhz - AudioController.minFmMhz);
    final exactStep = (rawMhz * 10).round() / 10.0;

    if ((exactStep - _lastTickMhz).abs() >= 0.2) {
      _lastTickMhz = exactStep;
      HapticFeedback.selectionClick();
    }
    widget.controller.scrubFmDial(exactStep);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final activeFm = controller.activeFmStation;
    final isFmPlaying = controller.isFmMode && controller.isPlaying;
    final dialMhz = controller.currentDialMhz;
    final compact = widget.isCompact;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10.w : 12.r,
        vertical: compact ? 7.h : 12.r,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3E1818), Color(0xFF230E0E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 14.r : 18.r),
        border: Border.all(
          color: const Color(0xFF4A1818),
          width: 2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1818),
            offset: Offset(compact ? 2.w : 4.w, compact ? 2.h : 4.h),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Fine-Tune Down (-0.1 MHz on tap, Prev Station on long-press)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.stepFmFrequency(-0.1);
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  controller.tunePreviousFmStation();
                },
                child: Container(
                  width: compact ? 28.w : 34.w,
                  height: compact ? 36.h : 52.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF3E8),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xFFD4A359),
                      width: 1.6.w,
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: const Color(0xFF4A1818),
                    size: compact ? 20.sp : 24.sp,
                  ),
                ),
              ),
              SizedBox(width: 8.w),

              // Free Manual Drag Analog Frequency Scale
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) => _onDialDrag(
                        details.localPosition.dx,
                        constraints.maxWidth,
                      ),
                      onHorizontalDragEnd: (_) {
                        HapticFeedback.mediumImpact();
                        controller
                            .tuneManualFrequency(controller.currentDialMhz);
                      },
                      onTapDown: (details) {
                        _onDialDrag(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        );
                        HapticFeedback.mediumImpact();
                        controller
                            .tuneManualFrequency(controller.currentDialMhz);
                      },
                      child: Container(
                        height: compact ? 36.h : 52.w,
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: compact ? 3.h : 5.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF9EE), Color(0xFFF3E2C7)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: const Color(0xFFD4A359),
                            width: 1.6.w,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    activeFm != null
                                        ? '${activeFm.name} • ${dialMhz.toStringAsFixed(1)} MHz'
                                        : 'FM RADIO • ${dialMhz.toStringAsFixed(1)} MHz',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.montserrat(
                                      fontSize: compact ? 8.2.sp : 8.8.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: const Color(0xFF4A1818),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4.w),
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
                                      fontSize: 7.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: compact ? 11.h : 20.h,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _AnalogDialScalePainter(
                                  currentMhz: dialMhz,
                                  stations: controller.fmStations,
                                  isLive: isFmPlaying,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(width: 8.w),

              // Fine-Tune Up (+0.1 MHz on tap, Next Station on long-press)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.stepFmFrequency(0.1);
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  controller.tuneNextFmStation();
                },
                child: Container(
                  width: compact ? 28.w : 34.w,
                  height: compact ? 36.h : 52.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF3E8),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xFFD4A359),
                      width: 1.6.w,
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFF4A1818),
                    size: compact ? 20.sp : 24.sp,
                  ),
                ),
              ),

              SizedBox(width: 8.w),

              // Quick Play / Pause FM Power Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (activeFm == null) {
                    controller.tuneManualFrequency(dialMhz);
                  } else {
                    controller.togglePlayPause();
                  }
                },
                child: Container(
                  width: compact ? 36.w : 46.w,
                  height: compact ? 36.w : 46.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isFmPlaying
                          ? [const Color(0xFFFF1744), const Color(0xFFB71C1C)]
                          : [const Color(0xFFFFFBF4), const Color(0xFFF3E2C7)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4A359),
                      width: 1.8.w,
                    ),
                  ),
                  child: controller.isFmLoading
                      ? Padding(
                          padding: EdgeInsets.all(9.r),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.0,
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
                          size: compact ? 18.sp : 22.sp,
                        ),
                ),
              ),
            ],
          ),

          // Station Preset Pills shown when expanded (full size)
          if (!compact) ...[
            SizedBox(height: 10.h),
            SizedBox(
              height: 30.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: controller.fmStations.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final station = controller.fmStations[index];
                  final isSelected =
                      (dialMhz - station.frequencyMhz).abs() < 0.05 &&
                          controller.isFmMode;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.playFmStation(station);
                    },
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
                            station.frequencyLabel,
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
        ],
      ),
    );
  }
}

class _AnalogDialScalePainter extends CustomPainter {
  final double currentMhz;
  final List<FmStation> stations;
  final bool isLive;

  _AnalogDialScalePainter({
    required this.currentMhz,
    required this.stations,
    required this.isLive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = const Color(0xFF4A1818).withOpacity(0.45)
      ..strokeWidth = 1.2;

    const totalTicks = 40;
    final step = size.width / totalTicks;

    for (int i = 0; i <= totalTicks; i++) {
      final x = i * step;
      final isMajor = i % 5 == 0;
      canvas.drawLine(
        Offset(x, isMajor ? 2 : 5),
        Offset(x, size.height - 2),
        tickPaint,
      );
    }

    final markerPaint = Paint()
      ..color = const Color(0xFFD4A359)
      ..style = PaintingStyle.fill;

    for (final st in stations) {
      final stRatio = ((st.frequencyMhz - AudioController.minFmMhz) /
              (AudioController.maxFmMhz - AudioController.minFmMhz))
          .clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(size.width * stRatio, size.height - 2.0),
        2.0,
        markerPaint,
      );
    }

    final ratio = ((currentMhz - AudioController.minFmMhz) /
            (AudioController.maxFmMhz - AudioController.minFmMhz))
        .clamp(0.0, 1.0);
    final needleX = size.width * ratio;

    final needlePaint = Paint()
      ..color = isLive ? const Color(0xFFD32F2F) : const Color(0xFF8E0000)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(needleX, 0),
      Offset(needleX, size.height),
      needlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalogDialScalePainter oldDelegate) =>
      oldDelegate.currentMhz != currentMhz || oldDelegate.isLive != isLive;
}

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

    canvas.drawLine(
      Offset(size.width * 0.25, 18),
      Offset(size.width * 0.78, 2),
      outline,
    );
    canvas.drawCircle(Offset(size.width * 0.78, 2), 3.5, brassFill);

    final handleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.22, 12, size.width * 0.56, 14),
      const Radius.circular(6),
    );
    canvas.drawRRect(handleRect, outline);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 24, size.width - 16, size.height - 28),
      const Radius.circular(14),
    );
    canvas.drawRRect(bodyRect, redFill);
    canvas.drawRRect(bodyRect, outline);

    final leftCenter = Offset(size.width * 0.26, size.height * 0.62);
    final rightCenter = Offset(size.width * 0.74, size.height * 0.62);
    canvas.drawCircle(leftCenter, 18, creamFill);
    canvas.drawCircle(leftCenter, 18, outline);
    canvas.drawCircle(leftCenter, 7, brassFill);

    canvas.drawCircle(rightCenter, 18, creamFill);
    canvas.drawCircle(rightCenter, 18, outline);
    canvas.drawCircle(rightCenter, 7, brassFill);

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
