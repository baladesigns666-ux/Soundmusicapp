import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_controller.dart';
import '../widgets/retro_tactile_button.dart';
import '../widgets/retro_radio_widgets.dart';
import '../widgets/crossfade_sheet.dart';
import '../widgets/song_tile.dart';
import 'collection_songs_screen.dart';
import 'now_playing_screen.dart';
import 'queue_screen.dart';

enum LibraryTab { songs, albums, artists, liked }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LibraryTab _activeTab = LibraryTab.songs;
  String _searchQuery = '';
  bool _showMiniSkipBadge = false;

  void _triggerMiniDoubleTapSkip(AudioController controller) {
    controller.skipForward10Seconds();
    setState(() => _showMiniSkipBadge = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showMiniSkipBadge = false);
    });
  }

  void _openCrossfadeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const CrossfadeBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioController.instance,
      builder: (context, _) {
        final controller = AudioController.instance;
        final query = _searchQuery.toLowerCase();

        final filteredSongs = controller.allSongs.where((song) {
          final matchesLiked = _activeTab != LibraryTab.liked ||
              controller.isLiked(song.id);
          final matchesSearch = song.title.toLowerCase().contains(query) ||
              (song.artist ?? '').toLowerCase().contains(query) ||
              (song.album ?? '').toLowerCase().contains(query);
          return matchesLiked && matchesSearch;
        }).toList();

        final filteredAlbums = controller.allAlbums.where((album) {
          return album.album.toLowerCase().contains(query) ||
              (album.artist ?? '').toLowerCase().contains(query);
        }).toList();

        final filteredArtists = controller.allArtists.where((artist) {
          return artist.artist.toLowerCase().contains(query);
        }).toList();

        final hasActiveMedia =
            controller.isFmMode || controller.currentSong != null;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF6E8D5),
                  Color(0xFFFAF3E8),
                  Color(0xFFFFFBF4),
                ],
                stops: [0.0, 0.35, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top Header: SOUND MUSIC + Crossfade + Queue
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 10.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE53935),
                                    Color(0xFFB71C1C),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: const Color(0xFF4A1818),
                                  width: 1.5.w,
                                ),
                              ),
                              child: Icon(
                                Icons.album_rounded,
                                color: const Color(0xFFFFFBF4),
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              'SOUND MUSIC',
                              style: GoogleFonts.montserrat(
                                fontSize: 21.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: const Color(0xFF4A1818),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            RetroTactileButton(
                              width: 42.w,
                              height: 42.w,
                              isPrimaryRed: controller.crossfadeSeconds > 0,
                              onTap: _openCrossfadeSheet,
                              child: Icon(
                                Icons.graphic_eq_rounded,
                                color: controller.crossfadeSeconds > 0
                                    ? Colors.white
                                    : const Color(0xFF4A1818),
                                size: 21.sp,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            RetroTactileButton(
                              width: 42.w,
                              height: 42.w,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QueueScreen()),
                              ),
                              child: Icon(
                                Icons.queue_music_rounded,
                                color: const Color(0xFF4A1818),
                                size: 21.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Top Playable Live FM Radio Deck
                  RetroTopFmConsole(controller: controller),

                  SizedBox(height: 12.h),

                  // Warm Cream Search Box
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Container(
                      height: 42.h,
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF4),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFF4A1818),
                          width: 1.8.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A1818).withOpacity(0.22),
                            offset: Offset(3.w, 3.h),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: const Color(0xFFC62828), size: 20.sp),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: TextField(
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: GoogleFonts.montserrat(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2B1212),
                              ),
                              decoration: InputDecoration(
                                hintText: 'SEARCH SONGS, ALBUMS, ARTISTS...',
                                hintStyle: GoogleFonts.montserrat(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: const Color(0xFF8D6E63),
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

                  SizedBox(height: 10.h),

                  // Category Tabs: SONGS | ALBUMS | ARTISTS | LIKED
                  SizedBox(
                    height: 36.h,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      children: [
                        _buildRetroTab(
                          label: 'SONGS (${controller.allSongs.length})',
                          selected: _activeTab == LibraryTab.songs,
                          onTap: () =>
                              setState(() => _activeTab = LibraryTab.songs),
                        ),
                        SizedBox(width: 10.w),
                        _buildRetroTab(
                          label: 'ALBUMS (${controller.allAlbums.length})',
                          selected: _activeTab == LibraryTab.albums,
                          onTap: () =>
                              setState(() => _activeTab = LibraryTab.albums),
                        ),
                        SizedBox(width: 10.w),
                        _buildRetroTab(
                          label: 'ARTISTS (${controller.allArtists.length})',
                          selected: _activeTab == LibraryTab.artists,
                          onTap: () =>
                              setState(() => _activeTab = LibraryTab.artists),
                        ),
                        SizedBox(width: 10.w),
                        _buildRetroTab(
                          label: 'LIKED (${controller.likedSongIds.length})',
                          selected: _activeTab == LibraryTab.liked,
                          onTap: () =>
                              setState(() => _activeTab = LibraryTab.liked),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Main Library Body
                  Expanded(
                    child: _buildActiveTabBody(
                      controller: controller,
                      filteredSongs: filteredSongs,
                      filteredAlbums: filteredAlbums,
                      filteredArtists: filteredArtists,
                    ),
                  ),

                  // Bottom Mini Player (Supports both Local Songs & Live FM Radio)
                  if (hasActiveMedia) _buildMiniPlayer(context, controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTabBody({
    required AudioController controller,
    required List<SongModel> filteredSongs,
    required List<AlbumModel> filteredAlbums,
    required List<ArtistModel> filteredArtists,
  }) {
    if (_activeTab == LibraryTab.albums) {
      if (filteredAlbums.isEmpty) {
        return const RetroRadioIllustration(message: 'NO ALBUMS FOUND');
      }
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14.w,
          mainAxisSpacing: 14.h,
          childAspectRatio: 0.84,
        ),
        itemCount: filteredAlbums.length,
        itemBuilder: (context, index) {
          final album = filteredAlbums[index];
          return GestureDetector(
            onTap: () {
              final albumSongs = controller.getSongsByAlbum(album.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CollectionSongsScreen(
                    title: album.album,
                    subtitle:
                        '${album.artist ?? 'Unknown Artist'} • ${albumSongs.length} Tracks',
                    songs: albumSongs,
                    artworkId: album.id,
                    artworkType: ArtworkType.ALBUM,
                  ),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBF4), Color(0xFFF6E8D5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFF4A1818),
                  width: 1.8.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A1818),
                    offset: Offset(3.w, 3.h),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: SizedBox(
                        width: double.infinity,
                        child: QueryArtworkWidget(
                          id: album.id,
                          type: ArtworkType.ALBUM,
                          nullArtworkWidget: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              Icons.album_rounded,
                              color: Colors.white,
                              size: 46.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    album.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2B1212),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${album.numOfSongs} TRACKS',
                    style: GoogleFonts.montserrat(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_activeTab == LibraryTab.artists) {
      if (filteredArtists.isEmpty) {
        return const RetroRadioIllustration(message: 'NO ARTISTS FOUND');
      }
      return ListView.builder(
        padding: EdgeInsets.only(bottom: 16.h),
        itemCount: filteredArtists.length,
        itemBuilder: (context, index) {
          final artist = filteredArtists[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            child: GestureDetector(
              onTap: () {
                final artistSongs = controller.getSongsByArtist(artist.id);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CollectionSongsScreen(
                      title: artist.artist,
                      subtitle: '${artistSongs.length} Tracks',
                      songs: artistSongs,
                      artworkId: artist.id,
                      artworkType: ArtworkType.ARTIST,
                    ),
                  ),
                );
              },
              child: Container(
                height: 70.h,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBF4), Color(0xFFF6E8D5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFF4A1818),
                    width: 1.8.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A1818).withOpacity(0.25),
                      offset: Offset(3.w, 3.h),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46.w,
                      height: 46.w,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF4A1818),
                          width: 2.w,
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artist.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2B1212),
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            '${artist.numberOfTracks ?? 0} TRACKS • ${artist.numberOfAlbums ?? 0} ALBUMS',
                            style: GoogleFonts.montserrat(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFC62828),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: const Color(0xFF4A1818),
                      size: 16.sp,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (filteredSongs.isEmpty) {
      return RetroRadioIllustration(
        message: _activeTab == LibraryTab.liked
            ? 'NO LIKED TRACKS'
            : 'NO LOCAL AUDIO FILES',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 16.h),
      itemCount: filteredSongs.length,
      itemBuilder: (context, index) {
        final song = filteredSongs[index];
        return SongTile(
          song: song,
          onTap: () {
            controller.playSong(song, customList: filteredSongs);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NowPlayingScreen(),
              ),
            );
          },
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
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFBF4), Color(0xFFF6E8D5)],
                ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFF4A1818),
            width: 1.8.w,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A1818),
              offset: Offset(2.w, 2.h),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: selected ? Colors.white : const Color(0xFF4A1818),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context, AudioController controller) {
    final isFm = controller.isFmMode;
    final fm = controller.activeFmStation;
    final song = controller.currentSong;

    final titleText = isFm ? fm!.name : song!.title;
    final subtitleText = isFm
        ? 'LIVE FM • ${fm!.frequencyLabel} (${fm.genre})'
        : _showMiniSkipBadge
            ? '+10 SEC >>'
            : '${song!.artist ?? 'Unknown Artist'} • ${song.album ?? 'Single'}';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFm
                ? [const Color(0xFF3E1818), const Color(0xFFB71C1C)]
                : [const Color(0xFFB71C1C), const Color(0xFFE53935)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFF4A1818),
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A1818),
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
                border: Border.all(color: const Color(0xFFD4A359), width: 2.w),
              ),
              child: ClipOval(
                child: isFm
                    ? Container(
                        color: const Color(0xFFFAF3E8),
                        child: Icon(Icons.radio_rounded,
                            color: const Color(0xFFB71C1C), size: 22.sp),
                      )
                    : QueryArtworkWidget(
                        id: song!.id,
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
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      color: isFm || _showMiniSkipBadge
                          ? const Color(0xFFFFE082)
                          : Colors.white.withOpacity(0.9),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => controller.togglePlayPause(),
              child: Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4A1818),
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
            GestureDetector(
              onTap: () => controller.playNext(),
              child: Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD4A359), width: 1.5.w),
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
