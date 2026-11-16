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
              colors: [Color(0xFFFFFBF4), Color(0xFFF6E8D5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
            border: Border(
              top: BorderSide(color: const Color(0xFF4A1818), width: 2.5.w),
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
                        color: const Color(0xFFC62828),
                        size: 22.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'CROSSFADE MIXER',
                        style: GoogleFonts.montserrat(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: const Color(0xFF4A1818),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: const Color(0xFF4A1818),
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
                  activeTrackColor: const Color(0xFFC62828),
                  inactiveTrackColor: const Color(0xFFE0CBB2),
                  thumbColor: const Color(0xFFE53935),
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
                        color: const Color(0xFF6D4C41),
                      ),
                    ),
                    Text(
                      '6S',
                      style: GoogleFonts.montserrat(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6D4C41),
                      ),
                    ),
                    Text(
                      '12S',
                      style: GoogleFonts.montserrat(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6D4C41),
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
                            : const Color(0xFF4A1818),
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
