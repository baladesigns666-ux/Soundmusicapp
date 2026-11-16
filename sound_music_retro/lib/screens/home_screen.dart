import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_controller.dart';
import '../widgets/retro_tactile_button.dart';
import '../widgets/song_tile.dart';
import 'now_playing_screen.dart';
import 'queue_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showLikedOnly = false;
  String _searchQuery = '';
  bool _showMiniSkipBadge = false;

  void _triggerMiniDoubleTapSkip(AudioController controller) {
    controller.skipForward10Seconds();
    setState(() => _showMiniSkipBadge = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showMiniSkipBadge = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioController.instance,
      builder: (context, _) {
        final controller = AudioController.instance;

        final filteredSongs = controller.allSongs.where((song) {
          final matchesTab =
              !_showLikedOnly || controller.isLiked(song.id);
          final matchesSearch = song.title
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (song.artist ?? '')
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase());
          return matchesTab && matchesSearch;
        }).toList();

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFCDD2),
                  Color(0xFFFFEBEE),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.25, 0.6],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Retro Top Deck Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 12.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10.w,
                                  height: 10.w,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF1744),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'RETRO TAPE DECK',
                                  style: TextStyle(
                                    fontSize: 21.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: const Color(0xFFB71C1C),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              'SWIPE RIGHT: NEXT  •  2X TAP: LIKE / +10S',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: const Color(0xFF616161),
                              ),
                            ),
                          ],
                        ),
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
                  ),

                  // Retro Search Box
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Container(
                      height: 46.h,
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFF8E0000),
                          width: 1.8.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD32F2F).withOpacity(0.22),
                            offset: Offset(3.w, 3.h),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: const Color(0xFFD32F2F), size: 20.sp),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: TextField(
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'SEARCH LOCAL TRACKS...',
                                hintStyle: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF9E9E9E),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 14.h),

                  // Retro Filter Switches
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        _buildRetroTab(
                          label: 'ALL TRACKS (${controller.allSongs.length})',
                          selected: !_showLikedOnly,
                          onTap: () => setState(() => _showLikedOnly = false),
                        ),
                        SizedBox(width: 12.w),
                        _buildRetroTab(
                          label: 'FAVORITES (${controller.likedSongIds.length})',
                          selected: _showLikedOnly,
                          onTap: () => setState(() => _showLikedOnly = true),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // Track List
                  Expanded(
                    child: filteredSongs.isEmpty
                        ? Center(
                            child: Text(
                              _showLikedOnly
                                  ? 'DOUBLE-TAP ANY SONG TO LIKE'
                                  : 'NO LOCAL AUDIO FILES FOUND',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: const Color(0xFF757575),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: 16.h),
                            itemCount: filteredSongs.length,
                            itemBuilder: (context, index) {
                              final song = filteredSongs[index];
                              return SongTile(
                                song: song,
                                onTap: () {
                                  controller.playSong(song,
                                      customList: filteredSongs);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const NowPlayingScreen(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),

                  // Bottom Retro Cassette Mini-Player
                  if (controller.currentSong != null)
                    _buildMiniPlayer(context, controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRetroTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFFFEBEE)],
                ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFF8E0000),
            width: 1.8.w,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E0000),
              offset: Offset(2.w, 2.h),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: selected ? Colors.white : const Color(0xFFB71C1C),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context, AudioController controller) {
    final song = controller.currentSong!;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFFFF1744)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFF6A0000),
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A0000),
              offset: Offset(4.w, 4.h),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.w),
              ),
              child: ClipOval(
                child: QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  nullArtworkWidget: Container(
                    color: Colors.white.withOpacity(0.2),
                    child: Icon(Icons.album_rounded,
                        color: Colors.white, size: 22.sp),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _showMiniSkipBadge
                        ? '+10 SEC SKIPPED >>'
                        : (song.artist ?? 'UNKNOWN ARTIST').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _showMiniSkipBadge
                          ? const Color(0xFFFFEB3B)
                          : Colors.white.withOpacity(0.88),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: controller.togglePlayPause,
              child: Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6A0000),
                    width: 1.8.w,
                  ),
                ),
                child: Icon(
                  controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: const Color(0xFFB71C1C),
                  size: 24.sp,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            // Mini Next Button: Single Tap = Next Song, Double Tap = +10s Skip
            GestureDetector(
              onTap: controller.playNext,
              onDoubleTap: () => _triggerMiniDoubleTapSkip(controller),
              child: Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5.w),
                ),
                child: Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
