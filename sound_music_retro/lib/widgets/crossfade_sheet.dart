import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_controller.dart';
import 'retro_tactile_button.dart';

class CrossfadeBottomSheet extends StatelessWidget {
  const CrossfadeBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioController.instance,
      builder: (context, _) {
        final controller = AudioController.instance;
        final fadeSec = controller.crossfadeSeconds;

        return Container(
          padding: EdgeInsets.fromLTRB(22.w, 18.h, 22.w, 28.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFEBEE)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
            border: Border(
              top: BorderSide(color: const Color(0xFF8E0000), width: 2.5.w),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        color: const Color(0xFFD32F2F),
                        size: 22.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'CROSSFADE MIXER',
                        style: GoogleFonts.montserrat(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: const Color(0xFFB71C1C),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: const Color(0xFF6A0000),
                        width: 1.5.w,
                      ),
                    ),
                    child: Text(
                      fadeSec == 0 ? 'OFF' : '${fadeSec.toInt()} SEC',
                      style: GoogleFonts.montserrat(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFD32F2F),
                  inactiveTrackColor: const Color(0xFFFFCDD2),
                  thumbColor: const Color(0xFFFF1744),
                  trackHeight: 6.h,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9.r),
                ),
                child: Slider(
                  value: fadeSec,
                  min: 0,
                  max: 12,
                  divisions: 12,
                  onChanged: (val) => controller.setCrossfadeDuration(val),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OFF',
                      style: GoogleFonts.montserrat(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF757575),
                      ),
                    ),
                    Text(
                      '6S',
                      style: GoogleFonts.montserrat(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF757575),
                      ),
                    ),
                    Text(
                      '12S',
                      style: GoogleFonts.montserrat(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [0.0, 3.0, 6.0, 10.0].map((preset) {
                  final isSelected = fadeSec.round() == preset.round();
                  return RetroTactileButton(
                    width: 72.w,
                    height: 38.h,
                    isPrimaryRed: isSelected,
                    onTap: () => controller.setCrossfadeDuration(preset),
                    child: Text(
                      preset == 0 ? 'OFF' : '${preset.toInt()}S',
                      style: GoogleFonts.montserrat(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFB71C1C),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
