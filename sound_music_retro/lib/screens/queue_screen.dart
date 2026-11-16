import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_controller.dart';
import '../widgets/retro_tactile_button.dart';
import '../widgets/retro_radio_widgets.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioController.instance,
      builder: (context, _) {
        final controller = AudioController.instance;
        final queue = controller.playQueue;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6E8D5), Color(0xFFFAF3E8)],
                stops: [0.0, 0.45],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
                    child: Row(
                      children: [
                        RetroTactileButton(
                          width: 42.w,
                          height: 42.w,
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: const Color(0xFF4A1818),
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'PLAY QUEUE (${queue.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: const Color(0xFF4A1818),
                            ),
                          ),
                        ),
                        if (queue.isNotEmpty)
                          RetroTactileButton(
                            width: 104.w,
                            height: 38.h,
                            isPrimaryRed: true,
                            onTap: () async {
                              await controller.clearQueue();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_sweep_rounded,
                                  color: Colors.white,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'CLEAR ALL',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: queue.isEmpty
                        ? const RetroRadioIllustration(
                            message: 'NO SONGS IN QUEUE',
                          )
                        : ListView.builder(
                            itemCount: queue.length,
                            itemBuilder: (context, index) {
                              final song = queue[index];
                              final isPlayingNow = !controller.isFmMode &&
                                  index == controller.currentIndex;
                              final isUserAdded = controller.userAddedQueueIds
                                  .contains(song.id);

                              return GestureDetector(
                                onTap: () => controller.playSong(song),
                                child: Container(
                                  margin: EdgeInsets.symmetric(
                                      horizontal: 16.w, vertical: 6.h),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14.w, vertical: 12.h),
                                  decoration: BoxDecoration(
                                    gradient: isPlayingNow
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFFFFCDD2),
                                              Color(0xFFFFFBF4),
                                            ],
                                          )
                                        : null,
                                    color: isPlayingNow
                                        ? null
                                        : const Color(0xFFFFFBF4),
                                    borderRadius: BorderRadius.circular(14.r),
                                    border: Border.all(
                                      color: isPlayingNow
                                          ? const Color(0xFFC62828)
                                          : isUserAdded
                                              ? const Color(0xFFD4A359)
                                              : const Color(0xFF4A1818)
                                                  .withOpacity(0.35),
                                      width: isPlayingNow ? 2.w : 1.5.w,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4A1818)
                                            .withOpacity(
                                                isPlayingNow ? 0.35 : 0.14),
                                        offset: Offset(3.w, 3.h),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28.w,
                                        height: 28.w,
                                        decoration: BoxDecoration(
                                          color: isPlayingNow
                                              ? const Color(0xFFC62828)
                                              : isUserAdded
                                                  ? const Color(0xFFD4A359)
                                                  : const Color(0xFFF6E8D5),
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w800,
                                              color: isPlayingNow
                                                  ? Colors.white
                                                  : const Color(0xFF4A1818),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    song.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        GoogleFonts.montserrat(
                                                      fontSize: 14.sp,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: isPlayingNow
                                                          ? const Color(
                                                              0xFFB71C1C)
                                                          : const Color(
                                                              0xFF2B1212),
                                                    ),
                                                  ),
                                                ),
                                                if (isUserAdded &&
                                                    !isPlayingNow) ...[
                                                  SizedBox(width: 6.w),
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 6.w,
                                                      vertical: 2.h,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFC62828),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6.r),
                                                    ),
                                                    child: Text(
                                                      'UP NEXT',
                                                      style: GoogleFonts
                                                          .montserrat(
                                                        fontSize: 8.sp,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              '${song.artist ?? 'Unknown Artist'} • ${song.album ?? 'Single'}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF6D4C41),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      if (isPlayingNow)
                                        Icon(
                                          Icons.graphic_eq_rounded,
                                          color: const Color(0xFFC62828),
                                          size: 22.sp,
                                        )
                                      else
                                        GestureDetector(
                                          onTap: () => controller
                                              .removeFromQueue(index),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: const Color(0xFF8D6E63),
                                            size: 20.sp,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
