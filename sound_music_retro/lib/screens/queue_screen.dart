import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/audio_controller.dart';
import '../widgets/retro_tactile_button.dart';

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
                colors: [Color(0xFFFFCDD2), Color(0xFFFFFFFF)],
                stops: [0.0, 0.35],
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
                            color: const Color(0xFFB71C1C),
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Text(
                          'TAPE QUEUE (${queue.length})',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: const Color(0xFFB71C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isPlayingNow = index == controller.currentIndex;

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
                                        Color(0xFFFFEBEE),
                                        Color(0xFFFFFFFF),
                                      ],
                                    )
                                  : null,
                              color: isPlayingNow ? null : Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: isPlayingNow
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFF8E0000).withOpacity(0.3),
                                width: isPlayingNow ? 2.w : 1.5.w,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD32F2F)
                                      .withOpacity(isPlayingNow ? 0.35 : 0.12),
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
                                        ? const Color(0xFFD32F2F)
                                        : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w800,
                                        color: isPlayingNow
                                            ? Colors.white
                                            : const Color(0xFFB71C1C),
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
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w800,
                                          color: isPlayingNow
                                              ? const Color(0xFFB71C1C)
                                              : const Color(0xFF212121),
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        (song.artist ?? 'UNKNOWN ARTIST')
                                            .toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.6,
                                          color: const Color(0xFF757575),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isPlayingNow)
                                  Icon(
                                    Icons.graphic_eq_rounded,
                                    color: const Color(0xFFD32F2F),
                                    size: 22.sp,
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
