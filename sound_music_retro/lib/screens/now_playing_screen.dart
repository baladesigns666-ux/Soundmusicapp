import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_controller.dart';
import '../widgets/retro_tactile_button.dart';
import '../widgets/crossfade_sheet.dart';
import 'queue_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vinylSpinController;
  bool _showBigHeart = false;
  String? _skipIndicatorText;
  Timer? _skipBadgeTimer;

  @override
  void initState() {
    super.initState();
    _vinylSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (AudioController.instance.isPlaying) {
      _vinylSpinController.repeat();
    }
  }

  @override
  void dispose() {
    _vinylSpinController.dispose();
    _skipBadgeTimer?.cancel();
    super.dispose();
  }

  void _showSkipBanner(String label) {
    _skipBadgeTimer?.cancel();
    setState(() => _skipIndicatorText = label);
    _skipBadgeTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _skipIndicatorText = null);
    });
  }

  void _openCrossfadeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const CrossfadeBottomSheet(),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioController.instance,
      builder: (context, _) {
        final controller = AudioController.instance;
        final song = controller.currentSong;

        if (controller.isPlaying && !_vinylSpinController.isAnimating) {
          _vinylSpinController.repeat();
        } else if (!controller.isPlaying && _vinylSpinController.isAnimating) {
          _vinylSpinController.stop();
        }

        if (song == null) {
          return const Scaffold(body: Center(child: Text('NO TRACK LOADED')));
        }

        final isLiked = controller.isLiked(song.id);

        return Scaffold(
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFCDD2),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFEBEE),
                ],
                stops: [0.0, 0.52, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w),
                child: Column(
                  children: [
                    SizedBox(height: 12.h),

                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RetroTactileButton(
                          width: 44.w,
                          height: 44.w,
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFFB71C1C),
                            size: 26.sp,
                          ),
                        ),
                        Text(
                          'SOUND MUSIC',
                          style: GoogleFonts.montserrat(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: const Color(0xFFB71C1C),
                          ),
                        ),
                        Row(
                          children: [
                            RetroTactileButton(
                              width: 44.w,
                              height: 44.w,
                              isPrimaryRed: controller.crossfadeSeconds > 0,
                              onTap: _openCrossfadeSheet,
                              child: Icon(
                                Icons.graphic_eq_rounded,
                                color: controller.crossfadeSeconds > 0
                                    ? Colors.white
                                    : const Color(0xFFB71C1C),
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            RetroTactileButton(
                              width: 44.w,
                              height: 44.w,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QueueScreen()),
                              ),
                              child: Icon(
                                Icons.queue_music_rounded,
                                color: const Color(0xFFB71C1C),
                                size: 22.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Rotating Retro Vinyl Record Disc
                    GestureDetector(
                      onDoubleTap: () {
                        controller.toggleLike(song.id);
                        setState(() => _showBigHeart = true);
                        Future.delayed(const Duration(milliseconds: 700), () {
                          if (mounted) setState(() => _showBigHeart = false);
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 280.w,
                            height: 280.w,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFFFEBEE),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(32.r),
                              border: Border.all(
                                color: const Color(0xFF8E0000),
                                width: 2.5.w,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8E0000),
                                  offset: Offset(6.w, 6.h),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Center(
                              child: RotationTransition(
                                turns: _vinylSpinController,
                                child: Container(
                                  width: 236.w,
                                  height: 236.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0xFF3A0000),
                                        Color(0xFF141414),
                                        Color(0xFF2B2B2B),
                                        Color(0xFF121212),
                                      ],
                                      stops: [0.25, 0.55, 0.78, 1.0],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFD32F2F),
                                      width: 3.w,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 126.w,
                                      height: 126.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3.w,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: QueryArtworkWidget(
                                          id: song.id,
                                          type: ArtworkType.AUDIO,
                                          artworkWidth: 126.w,
                                          artworkHeight: 126.w,
                                          nullArtworkWidget: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color(0xFFFF1744),
                                                  Color(0xFFB71C1C),
                                                ],
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.music_note_rounded,
                                              color: Colors.white,
                                              size: 54.sp,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Container(
                            width: 18.w,
                            height: 18.w,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFB71C1C),
                                width: 3.w,
                              ),
                            ),
                          ),

                          if (_skipIndicatorText != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 18.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF1744),
                                    Color(0xFFB71C1C),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.w,
                                ),
                              ),
                              child: Text(
                                _skipIndicatorText!,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),

                          if (_showBigHeart)
                            Container(
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD32F2F),
                                  width: 2.5.w,
                                ),
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: const Color(0xFFFF1744),
                                size: 54.sp,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Track Title, Artist & Album Metadata + Like Button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                '${song.artist ?? 'Unknown Artist'} • ${song.album ?? 'Single'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB71C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        RetroTactileButton(
                          width: 46.w,
                          height: 46.w,
                          isCircular: true,
                          onTap: () => controller.toggleLike(song.id),
                          child: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: const Color(0xFFD32F2F),
                            size: 24.sp,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // Seek Slider & Time
                    StreamBuilder<Duration>(
                      stream: controller.player.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final total =
                            controller.player.duration ?? Duration.zero;
                        final maxVal = total.inMilliseconds > 0
                            ? total.inMilliseconds.toDouble()
                            : 1.0;
                        final currentVal = position.inMilliseconds
                            .toDouble()
                            .clamp(0.0, maxVal);

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFFD32F2F),
                                inactiveTrackColor: const Color(0xFFFFCDD2),
                                thumbColor: const Color(0xFFFF1744),
                                trackHeight: 5.h,
                                thumbShape: RoundSliderThumbShape(
                                  enabledThumbRadius: 8.r,
                                ),
                              ),
                              child: Slider(
                                value: currentVal,
                                max: maxVal,
                                onChanged: (val) {
                                  controller.player.seek(
                                    Duration(milliseconds: val.toInt()),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6.w),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(
                                          color: const Color(0xFFFFCDD2)),
                                    ),
                                    child: Text(
                                      _formatDuration(position),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFB71C1C),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(
                                          color: const Color(0xFFFFCDD2)),
                                    ),
                                    child: Text(
                                      _formatDuration(total),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF616161),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    SizedBox(height: 18.h),

                    // Tactile Transport Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RetroTactileButton(
                          width: 42.w,
                          height: 42.w,
                          onTap: controller.toggleShuffle,
                          child: Icon(
                            Icons.shuffle_rounded,
                            color: controller.isShuffle
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF9E9E9E),
                            size: 20.sp,
                          ),
                        ),
                        RetroTactileButton(
                          width: 54.w,
                          height: 54.w,
                          onTap: controller.playPrevious,
                          onDoubleTap: () {
                            controller.skipBackward10Seconds();
                            _showSkipBanner('<< -10 SEC');
                          },
                          child: Icon(
                            Icons.skip_previous_rounded,
                            color: const Color(0xFFB71C1C),
                            size: 32.sp,
                          ),
                        ),
                        RetroTactileButton(
                          width: 72.w,
                          height: 72.w,
                          isPrimaryRed: true,
                          isCircular: true,
                          onTap: controller.togglePlayPause,
                          child: Icon(
                            controller.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 38.sp,
                          ),
                        ),
                        RetroTactileButton(
                          width: 54.w,
                          height: 54.w,
                          onTap: controller.playNext,
                          onDoubleTap: () {
                            controller.skipForward10Seconds();
                            _showSkipBanner('+10 SEC >>');
                          },
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: const Color(0xFFB71C1C),
                            size: 32.sp,
                          ),
                        ),
                        RetroTactileButton(
                          width: 42.w,
                          height: 42.w,
                          onTap: controller.toggleRepeat,
                          child: Icon(
                            controller.loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: controller.loopMode != LoopMode.off
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF9E9E9E),
                            size: 20.sp,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 26.h),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
