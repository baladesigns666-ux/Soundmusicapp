import 'dart:async';
import 'dart:math' as math;
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
    with TickerProviderStateMixin {
  late final AnimationController _vinylSpinController;
  late final AnimationController _bgGradientController;
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
    _bgGradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    if (AudioController.instance.isPlaying) {
      _vinylSpinController.repeat();
    }
  }

  @override
  void dispose() {
    _vinylSpinController.dispose();
    _bgGradientController.dispose();
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
        final isFm = controller.isFmMode;
        final fm = controller.activeFmStation;
        final song = controller.currentSong;

        if (controller.isPlaying && !_vinylSpinController.isAnimating) {
          _vinylSpinController.repeat();
        } else if (!controller.isPlaying && _vinylSpinController.isAnimating) {
          _vinylSpinController.stop();
        }

        if (!isFm && song == null) {
          return const Scaffold(body: Center(child: Text('NO TRACK LOADED')));
        }

        final isLiked = !isFm && controller.isLiked(song!.id);

        return Scaffold(
          body: AnimatedBuilder(
            animation: _bgGradientController,
            builder: (context, child) {
              final t = _bgGradientController.value;
              final angle = t * math.pi * 2;
              final alignX = math.cos(angle) * 0.45;
              final alignY = math.sin(angle) * 0.45;

              final topColor = Color.lerp(
                const Color(0xFFF6E8D5),
                const Color(0xFFFFCDD2),
                t * 0.65,
              )!;
              final midColor = Color.lerp(
                const Color(0xFFFFFBF4),
                const Color(0xFFFAF0DF),
                t,
              )!;
              final bottomColor = Color.lerp(
                const Color(0xFFF3DEC0),
                const Color(0xFFF8BBD0),
                (1.0 - t) * 0.55,
              )!;

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [topColor, midColor, bottomColor],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment(-0.8 + alignX, -1.0),
                    end: Alignment(0.8 - alignX, 1.0 + alignY * 0.2),
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle warm ambient breathing radial glow behind the turntable
                    Positioned(
                      top: 90.h + (math.sin(angle) * 18.h),
                      left: 24.w + (math.cos(angle) * 16.w),
                      child: Container(
                        width: 310.w,
                        height: 310.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFE53935).withOpacity(
                                  controller.isPlaying ? 0.16 : 0.07),
                              const Color(0xFFD4A359).withOpacity(0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
              );
            },
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
                            color: const Color(0xFF4A1818),
                            size: 26.sp,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              isFm ? Icons.radio_rounded : Icons.album_rounded,
                              color: const Color(0xFFC62828),
                              size: 16.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              isFm ? 'LIVE FM RADIO' : 'SOUND MUSIC',
                              style: GoogleFonts.montserrat(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                color: const Color(0xFF4A1818),
                              ),
                            ),
                          ],
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
                                    : const Color(0xFF4A1818),
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
                                color: const Color(0xFF4A1818),
                                size: 22.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Refined Retro Turntable Plinth + Tonearm + Rotating Vinyl Disc
                    GestureDetector(
                      onDoubleTap: isFm
                          ? null
                          : () {
                              controller.toggleLike(song!.id);
                              setState(() => _showBigHeart = true);
                              Future.delayed(const Duration(milliseconds: 700),
                                  () {
                                if (mounted) {
                                  setState(() => _showBigHeart = false);
                                }
                              });
                            },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 286.w,
                            height: 286.w,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFFBF4),
                                  Color(0xFFF3E2C7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(32.r),
                              border: Border.all(
                                color: const Color(0xFF4A1818),
                                width: 2.5.w,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A1818),
                                  offset: Offset(6.w, 6.h),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 12.h,
                                  left: 12.w,
                                  child: _buildTurntableScrew(),
                                ),
                                Positioned(
                                  bottom: 12.h,
                                  left: 12.w,
                                  child: _buildTurntableScrew(),
                                ),
                                Positioned(
                                  bottom: 12.h,
                                  right: 12.w,
                                  child: _buildTurntableScrew(),
                                ),
                                Center(
                                  child: RotationTransition(
                                    turns: _vinylSpinController,
                                    child: Container(
                                      width: 236.w,
                                      height: 236.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const RadialGradient(
                                          colors: [
                                            Color(0xFF3A1212),
                                            Color(0xFF141010),
                                            Color(0xFF2B2222),
                                            Color(0xFF120E0E),
                                          ],
                                          stops: [0.25, 0.55, 0.78, 1.0],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFD4A359),
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
                                              color: const Color(0xFFFFFBF4),
                                              width: 3.w,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: isFm
                                                ? Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Color(0xFFE53935),
                                                          Color(0xFFB71C1C),
                                                        ],
                                                      ),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.radio_rounded,
                                                          color: Colors.white,
                                                          size: 38.sp,
                                                        ),
                                                        SizedBox(height: 4.h),
                                                        Text(
                                                          fm!.frequencyLabel,
                                                          style: GoogleFonts
                                                              .montserrat(
                                                            color: const Color(
                                                                0xFFFFE082),
                                                            fontSize: 11.sp,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : QueryArtworkWidget(
                                                    id: song!.id,
                                                    type: ArtworkType.AUDIO,
                                                    artworkWidth: 126.w,
                                                    artworkHeight: 126.w,
                                                    nullArtworkWidget:
                                                        Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            Color(0xFFE53935),
                                                            Color(0xFFB71C1C),
                                                          ],
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .music_note_rounded,
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
                                Positioned(
                                  top: 10.h,
                                  right: 10.w,
                                  child: SizedBox(
                                    width: 68.w,
                                    height: 120.h,
                                    child: CustomPaint(
                                      painter: _TurntableTonearmPainter(
                                        isPlaying: controller.isPlaying,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            width: 18.w,
                            height: 18.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBF4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF4A1818),
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
                                    Color(0xFFE53935),
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
                                color: const Color(0xFFFFFBF4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFC62828),
                                  width: 2.5.w,
                                ),
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: const Color(0xFFE53935),
                                size: 54.sp,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Track / FM Station Info + Like Button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFm ? fm!.name : song!.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF2B1212),
                                ),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                isFm
                                    ? '${fm!.frequencyLabel} • ${fm.genre}'
                                    : '${song!.artist ?? 'Unknown Artist'} • ${song.album ?? 'Single'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFC62828),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isFm) ...[
                          SizedBox(width: 12.w),
                          RetroTactileButton(
                            width: 46.w,
                            height: 46.w,
                            isCircular: true,
                            onTap: () => controller.toggleLike(song!.id),
                            child: Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: const Color(0xFFC62828),
                              size: 24.sp,
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // Seek Slider (Local Songs) or Live Broadcast Bar (FM Radio)
                    if (isFm)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E1818),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: const Color(0xFFD4A359),
                            width: 1.8.w,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.sensors_rounded,
                                    color: const Color(0xFFFFE082), size: 20.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'LIVE RADIO STREAM',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              fm!.frequencyLabel,
                              style: GoogleFonts.montserrat(
                                color: const Color(0xFFFFE082),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      StreamBuilder<Duration>(
                        stream: controller.activePositionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final total = controller.currentTrackDuration;
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
                                  activeTrackColor: const Color(0xFFC62828),
                                  inactiveTrackColor: const Color(0xFFE0CBB2),
                                  thumbColor: const Color(0xFFE53935),
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
                                        color: const Color(0xFFFFFBF4),
                                        borderRadius: BorderRadius.circular(6.r),
                                        border: Border.all(
                                            color: const Color(0xFFD4A359)),
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
                                        color: const Color(0xFFFFFBF4),
                                        borderRadius: BorderRadius.circular(6.r),
                                        border: Border.all(
                                            color: const Color(0xFFD4A359)),
                                      ),
                                      child: Text(
                                        _formatDuration(total),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6D4C41),
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
                                ? const Color(0xFFC62828)
                                : const Color(0xFF8D6E63),
                            size: 20.sp,
                          ),
                        ),
                        RetroTactileButton(
                          width: 54.w,
                          height: 54.w,
                          onTap: () => controller.playPrevious(),
                          onLongPress: () {
                            controller.skipBackward10Seconds();
                            _showSkipBanner(isFm ? 'PREV FM' : '<< -10 SEC');
                          },
                          child: Icon(
                            Icons.skip_previous_rounded,
                            color: const Color(0xFF4A1818),
                            size: 32.sp,
                          ),
                        ),
                        RetroTactileButton(
                          width: 72.w,
                          height: 72.w,
                          isPrimaryRed: true,
                          isCircular: true,
                          onTap: () => controller.togglePlayPause(),
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
                          onTap: () => controller.playNext(),
                          onLongPress: () {
                            controller.skipForward10Seconds();
                            _showSkipBanner(isFm ? 'NEXT FM' : '+10 SEC >>');
                          },
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: const Color(0xFF4A1818),
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
                                ? const Color(0xFFC62828)
                                : const Color(0xFF8D6E63),
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

  Widget _buildTurntableScrew() {
    return Container(
      width: 9.w,
      height: 9.w,
      decoration: BoxDecoration(
        color: const Color(0xFFD4A359),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF4A1818), width: 1.5.w),
      ),
    );
  }
}

class _TurntableTonearmPainter extends CustomPainter {
  final bool isPlaying;

  _TurntableTonearmPainter({required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.72, 16);
    final tip = isPlaying
        ? Offset(size.width * 0.22, size.height * 0.78)
        : Offset(size.width * 0.65, size.height * 0.72);

    final armPaint = Paint()
      ..color = const Color(0xFF4A1818)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(pivot, tip, armPaint);

    final baseFill = Paint()..color = const Color(0xFFD4A359);
    final baseStroke = Paint()
      ..color = const Color(0xFF4A1818)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(pivot, 11, baseFill);
    canvas.drawCircle(pivot, 11, baseStroke);
    canvas.drawCircle(pivot, 4, Paint()..color = const Color(0xFFFFFBF4));

    final headPaint = Paint()..color = const Color(0xFFC62828);
    canvas.drawCircle(tip, 6, headPaint);
    canvas.drawCircle(tip, 6, baseStroke);
  }

  @override
  bool shouldRepaint(covariant _TurntableTonearmPainter oldDelegate) =>
      oldDelegate.isPlaying != isPlaying;
}
