import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_controller.dart';

class SongTile extends StatefulWidget {
  final SongModel song;
  final VoidCallback onTap;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  double _dragOffset = 0.0;
  bool _showHeartOverlay = false;

  void _handleDoubleTap() {
    AudioController.instance.toggleLike(widget.song.id);
    setState(() => _showHeartOverlay = true);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showHeartOverlay = false);
    });
  }

  void _handleSwipeRightComplete() {
    AudioController.instance.addToPlayNext(widget.song);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB71C1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.white, width: 1.5.w),
        ),
        content: Row(
          children: [
            Icon(Icons.playlist_play_rounded, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'NEXT TRACK: ${widget.song.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AudioController.instance;
    final isCurrent = controller.currentSong?.id == widget.song.id;
    final isLiked = controller.isLiked(widget.song.id);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: _handleDoubleTap,
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 0 || _dragOffset > 0) {
            setState(() {
              _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 95.w);
            });
          }
        },
        onHorizontalDragEnd: (_) {
          if (_dragOffset >= 65.w) {
            _handleSwipeRightComplete();
          }
          setState(() => _dragOffset = 0.0);
        },
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Background Swipe Action Indicator (Retro Cassette Strip)
            if (_dragOffset > 5)
              Container(
                height: 70.h,
                width: double.infinity,
                padding: EdgeInsets.only(left: 18.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFF8E0000),
                    width: 2.w,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.queue_play_next_rounded,
                        color: Colors.white, size: 22.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'PLAY NEXT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

            // Foreground Retro Cassette Song Card
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Container(
                height: 70.h,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  gradient: isCurrent
                      ? const LinearGradient(
                          colors: [Color(0xFFFFCDD2), Color(0xFFFFFFFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF8E0000).withOpacity(0.35),
                    width: isCurrent ? 2.w : 1.5.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isCurrent
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFFD32F2F).withOpacity(0.18),
                      offset: Offset(3.w, 3.h),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Vinyl-Styled Album Art Frame
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF8E0000),
                          width: 2.w,
                        ),
                      ),
                      child: ClipOval(
                        child: QueryArtworkWidget(
                          id: widget.song.id,
                          type: ArtworkType.AUDIO,
                          nullArtworkWidget: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              Icons.album_rounded,
                              color: Colors.white,
                              size: 24.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: isCurrent
                                  ? const Color(0xFFB71C1C)
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            (widget.song.artist ?? 'UNKNOWN ARTIST')
                                .toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 8.w),

                    // Liked Heart Status
                    GestureDetector(
                      onTap: () => controller.toggleLike(widget.song.id),
                      child: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isLiked
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF9E9E9E),
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Double-Tap Heart Burst Feedback
            if (_showHeartOverlay)
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD32F2F),
                        width: 2.w,
                      ),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: const Color(0xFFFF1744),
                      size: 32.sp,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
