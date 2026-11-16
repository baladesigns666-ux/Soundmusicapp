import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_controller.dart';
import '../widgets/retro_tactile_button.dart';
import '../widgets/retro_radio_widgets.dart';
import '../widgets/song_tile.dart';
import 'now_playing_screen.dart';

class CollectionSongsScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<SongModel> songs;
  final int artworkId;
  final ArtworkType artworkType;

  const CollectionSongsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.artworkId,
    required this.artworkType,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioController.instance,
      builder: (context, _) {
        final controller = AudioController.instance;

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
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB71C1C),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                subtitle,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF616161),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (songs.isNotEmpty)
                          RetroTactileButton(
                            width: 84.w,
                            height: 40.h,
                            isPrimaryRed: true,
                            onTap: () {
                              controller.playSong(songs.first,
                                  customList: songs);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NowPlayingScreen(),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 20.sp),
                                SizedBox(width: 2.w),
                                Text(
                                  'PLAY',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w800,
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
                    child: songs.isEmpty
                        ? const RetroRadioIllustration(
                            message: 'NO TRACKS FOUND',
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: 16.h),
                            itemCount: songs.length,
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              return SongTile(
                                song: song,
                                onTap: () {
                                  controller.playSong(song, customList: songs);
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
