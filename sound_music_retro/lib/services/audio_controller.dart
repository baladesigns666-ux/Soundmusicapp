import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FmStation {
  final String id;
  final String name;
  final String frequency;
  final String genre;
  final String streamUrl;

  const FmStation({
    required this.id,
    required this.name,
    required this.frequency,
    required this.genre,
    required this.streamUrl,
  });
}

class AudioController extends ChangeNotifier {
  AudioController._();
  static final AudioController instance = AudioController._();

  // Primary player bound to just_audio_background (Lock Screen & Notification Bar)
  final AudioPlayer player = AudioPlayer();

  // Secondary tail player with handleAudioFocus: false so Android never interrupts primary playback
  final AudioPlayer _fadeOutPlayer = AudioPlayer(
    handleAudioFocus: false,
    androidApplyAudioAttributes: false,
  );

  final OnAudioQuery audioQuery = OnAudioQuery();

  // Live Playable FM Radio Stations (Tamil, Retro Classics, Hindi & Chill)
  final List<FmStation> fmStations = const [
    FmStation(
      id: 'fm_tamil_retro',
      name: 'TAMIL RETRO FM',
      frequency: '98.3 MHz',
      genre: '80s & 90s Classics',
      streamUrl: 'https://stream.zeno.fm/0r0xa792kwzuv',
    ),
    FmStation(
      id: 'fm_ilayaraja',
      name: 'RAJA MELODIES',
      frequency: '101.4 MHz',
      genre: 'Evergreen Maestro Hits',
      streamUrl: 'https://stream.zeno.fm/4d61y12021zuv',
    ),
    FmStation(
      id: 'fm_chennai_live',
      name: 'CHENNAI AIR FM',
      frequency: '102.3 MHz',
      genre: 'Kollywood Superhits',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio022/playlist.m3u8',
    ),
    FmStation(
      id: 'fm_retro_bollywood',
      name: 'VINTAGE GOLD FM',
      frequency: '104.8 MHz',
      genre: 'Golden Retro Hits',
      streamUrl: 'https://stream.zeno.fm/2y96n36661zuv',
    ),
    FmStation(
      id: 'fm_lofi_radio',
      name: 'ANALOG LO-FI FM',
      frequency: '106.4 MHz',
      genre: 'Late Night Vinyl Beats',
      streamUrl: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
    ),
  ];

  FmStation? activeFmStation;
  bool isFmLoading = false;
  String? fmErrorMessage;

  List<SongModel> allSongs = [];
  List<AlbumModel> allAlbums = [];
  List<ArtistModel> allArtists = [];
  List<SongModel> playQueue = [];
  Set<int> likedSongIds = {};

  int _upNextInsertedCount = 0;

  int currentIndex = -1;
  bool isPlaying = false;
  bool isShuffle = false;
  LoopMode loopMode = LoopMode.off;

  double crossfadeSeconds = 4.0;
  bool _isTransitioning = false;
  String? _tempArtDir;

  bool get isFmMode => activeFmStation != null;

  SongModel? get currentSong =>
      (!isFmMode && currentIndex >= 0 && currentIndex < playQueue.length)
          ? playQueue[currentIndex]
          : null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLikes = prefs.getStringList('liked_songs') ?? [];
    likedSongIds = savedLikes.map((e) => int.parse(e)).toSet();
    crossfadeSeconds = prefs.getDouble('crossfade_seconds') ?? 4.0;

    final cacheDir = await getTemporaryDirectory();
    _tempArtDir = '${cacheDir.path}/album_arts';
    await Directory(_tempArtDir!).create(recursive: true);

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.completed) {
        isFmLoading = false;
      }
      if (!isFmMode &&
          state.processingState == ProcessingState.completed &&
          !_isTransitioning) {
        _advanceToNextTrack(withCrossfade: false);
      }
      notifyListeners();
    });

    // Trigger Crossfade smoothly when remaining time enters crossfadeSeconds window (Local tracks only)
    player.positionStream.listen((position) {
      if (isFmMode ||
          crossfadeSeconds <= 0 ||
          _isTransitioning ||
          !player.playing ||
          playQueue.isEmpty) {
        return;
      }
      final total = player.duration;
      if (total == null || total.inSeconds <= (crossfadeSeconds + 3)) return;

      final remainingMs = (total - position).inMilliseconds;
      final fadeWindowMs = (crossfadeSeconds * 1000).toInt();

      if (remainingMs > 250 && remainingMs <= fadeWindowMs) {
        _advanceToNextTrack(withCrossfade: true);
      }
    });
  }

  /// Play Live FM Radio Stream with Lock Screen Notification Bar integration
  Future<void> playFmStation(FmStation station) async {
    fmErrorMessage = null;
    isFmLoading = true;
    activeFmStation = station;
    notifyListeners();

    try {
      await _fadeOutPlayer.stop();
      await player.stop();
      await player.setVolume(1.0);

      final mediaItem = MediaItem(
        id: station.id,
        album: 'LIVE FM • ${station.frequency}',
        title: '${station.name} (${station.frequency})',
        artist: station.genre,
      );

      await player.setAudioSource(
        AudioSource.uri(Uri.parse(station.streamUrl), tag: mediaItem),
      );
      await player.play();
    } catch (e) {
      fmErrorMessage = 'UNABLE TO TUNE ${station.frequency} - CHECK INTERNET';
      debugPrint('FM playback error: $e');
    } finally {
      isFmLoading = false;
      notifyListeners();
    }
  }

  Future<void> tuneNextFmStation() async {
    if (fmStations.isEmpty) return;
    if (activeFmStation == null) {
      await playFmStation(fmStations.first);
      return;
    }
    final idx = fmStations.indexWhere((s) => s.id == activeFmStation!.id);
    final nextIdx = (idx + 1) % fmStations.length;
    await playFmStation(fmStations[nextIdx]);
  }

  Future<void> tunePreviousFmStation() async {
    if (fmStations.isEmpty) return;
    if (activeFmStation == null) {
      await playFmStation(fmStations.first);
      return;
    }
    final idx = fmStations.indexWhere((s) => s.id == activeFmStation!.id);
    final prevIdx = (idx - 1 + fmStations.length) % fmStations.length;
    await playFmStation(fmStations[prevIdx]);
  }

  Future<void> stopFmAndSwitchToLocal() async {
    if (!isFmMode) return;
    activeFmStation = null;
    fmErrorMessage = null;
    isFmLoading = false;
    await player.stop();
    notifyListeners();
  }

  Future<void> setCrossfadeDuration(double seconds) async {
    crossfadeSeconds = seconds.clamp(0.0, 12.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('crossfade_seconds', crossfadeSeconds);
  }

  Future<Uri?> _resolveArtworkUri(int songId) async {
    if (_tempArtDir == null) return null;
    try {
      final file = File('$_tempArtDir/art_$songId.jpg');
      if (await file.exists()) {
        return Uri.file(file.path);
      }
      final Uint8List? bytes = await audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 400,
      );
      if (bytes != null && bytes.isNotEmpty) {
        await file.writeAsBytes(bytes, flush: true);
        return Uri.file(file.path);
      }
    } catch (_) {}
    return null;
  }

  Future<MediaItem> _buildMediaItem(SongModel song) async {
    final artUri = await _resolveArtworkUri(song.id);
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Sound Music',
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: artUri,
    );
  }

  Future<void> loadLocalLibrary() async {
    allSongs = await audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    allSongs = allSongs.where((s) => (s.duration ?? 0) > 15000).toList();

    allAlbums = await audioQuery.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    allArtists = await audioQuery.queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    if (playQueue.isEmpty) {
      playQueue = List.from(allSongs);
    }
    notifyListeners();
  }

  List<SongModel> getSongsByAlbum(int albumId) {
    return allSongs.where((s) => s.albumId == albumId).toList();
  }

  List<SongModel> getSongsByArtist(int artistId) {
    return allSongs.where((s) => s.artistId == artistId).toList();
  }

  Future<void> playSong(SongModel song, {List<SongModel>? customList}) async {
    activeFmStation = null;
    fmErrorMessage = null;
    isFmLoading = false;

    if (customList != null) {
      playQueue = List.from(customList);
    } else if (playQueue.isEmpty) {
      playQueue = List.from(allSongs);
    }

    int idx = playQueue.indexWhere((s) => s.id == song.id);
    if (idx == -1) {
      playQueue.insert(0, song);
      idx = 0;
    }

    _upNextInsertedCount = 0;
    currentIndex = idx;
    await _loadImmediateOnPrimary();
  }

  Future<void> _loadImmediateOnPrimary() async {
    final song = currentSong;
    if (song == null || song.uri == null) return;

    try {
      await _fadeOutPlayer.stop();
      final mediaItem = await _buildMediaItem(song);
      await player.setVolume(1.0);
      await player.setAudioSource(
        AudioSource.uri(Uri.parse(song.uri!), tag: mediaItem),
      );
      await player.play();
      notifyListeners();
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  Future<void> _advanceToNextTrack({required bool withCrossfade}) async {
    if (isFmMode) {
      await tuneNextFmStation();
      return;
    }
    if (_isTransitioning || playQueue.isEmpty) return;

    int nextIdx;
    if (loopMode == LoopMode.one && !withCrossfade) {
      await player.seek(Duration.zero);
      await player.play();
      return;
    } else if (loopMode == LoopMode.one && withCrossfade) {
      nextIdx = currentIndex;
    } else if (currentIndex + 1 < playQueue.length) {
      nextIdx = currentIndex + 1;
    } else if (loopMode == LoopMode.all || playQueue.length > 1) {
      nextIdx = 0;
    } else {
      return;
    }

    _isTransitioning = true;
    try {
      final outgoingSong = currentSong;
      final incomingSong = playQueue[nextIdx];

      if (_upNextInsertedCount > 0) {
        _upNextInsertedCount--;
      }

      if (withCrossfade &&
          crossfadeSeconds > 0 &&
          outgoingSong != null &&
          outgoingSong.uri != null &&
          incomingSong.uri != null) {
        final fadeDuration =
            Duration(milliseconds: (crossfadeSeconds * 1000).toInt());

        await _fadeOutPlayer.stop();
        await _fadeOutPlayer.setVolume(1.0);
        await _fadeOutPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(outgoingSong.uri!)),
        );

        final handoffPos = player.position + const Duration(milliseconds: 60);
        await _fadeOutPlayer.seek(handoffPos);
        await _fadeOutPlayer.play();

        currentIndex = nextIdx;
        notifyListeners();

        final nextMediaItem = await _buildMediaItem(incomingSong);
        await player.setVolume(0.0);
        await player.setAudioSource(
          AudioSource.uri(Uri.parse(incomingSong.uri!), tag: nextMediaItem),
        );
        await player.play();

        const int steps = 30;
        final stepMs =
            (fadeDuration.inMilliseconds / steps).round().clamp(25, 400);

        for (int i = 1; i <= steps; i++) {
          await Future.delayed(Duration(milliseconds: stepMs));
          final t = i / steps;
          final outGain = math.cos(t * math.pi / 2).clamp(0.0, 1.0);
          final inGain = math.sin(t * math.pi / 2).clamp(0.0, 1.0);

          await _fadeOutPlayer.setVolume(outGain);
          await player.setVolume(inGain);
        }

        await player.setVolume(1.0);
        await _fadeOutPlayer.stop();
      } else {
        currentIndex = nextIdx;
        await _loadImmediateOnPrimary();
      }
    } catch (e) {
      debugPrint('Crossfade transition error: $e');
      await player.setVolume(1.0);
      await _fadeOutPlayer.stop();
    } finally {
      _isTransitioning = false;
      notifyListeners();
    }
  }

  /// FIFO Play-Next Queue: 1st added song stays 1st, 2nd added song stays 2nd
  void addToPlayNext(SongModel song) {
    if (playQueue.isEmpty || currentIndex == -1) {
      playQueue = [song, ...allSongs.where((s) => s.id != song.id)];
      _upNextInsertedCount = 1;
      notifyListeners();
      return;
    }

    final existingIdx = playQueue.indexWhere((s) => s.id == song.id);
    if (existingIdx == currentIndex) return;

    if (existingIdx != -1) {
      if (existingIdx > currentIndex &&
          existingIdx <= currentIndex + _upNextInsertedCount) {
        _upNextInsertedCount--;
      }
      playQueue.removeAt(existingIdx);
      if (existingIdx < currentIndex) {
        currentIndex--;
      }
    }

    final insertPosition =
        (currentIndex + 1 + _upNextInsertedCount).clamp(0, playQueue.length);
    playQueue.insert(insertPosition, song);
    _upNextInsertedCount++;
    notifyListeners();
  }

  Future<void> toggleLike(int songId) async {
    if (likedSongIds.contains(songId)) {
      likedSongIds.remove(songId);
    } else {
      likedSongIds.add(songId);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'liked_songs',
      likedSongIds.map((e) => e.toString()).toList(),
    );
  }

  bool isLiked(int songId) => likedSongIds.contains(songId);

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await _fadeOutPlayer.pause();
      await player.pause();
    } else {
      if (isFmMode) {
        await player.play();
      } else if (currentSong == null && allSongs.isNotEmpty) {
        await playSong(allSongs.first);
      } else {
        await player.play();
      }
    }
    notifyListeners();
  }

  Future<void> skipForward10Seconds() async {
    if (isFmMode) {
      await tuneNextFmStation();
      return;
    }
    final duration = player.duration;
    if (duration == null) return;
    final target = player.position + const Duration(seconds: 10);
    if (target >= duration) {
      await playNext();
    } else {
      await player.seek(target);
    }
  }

  Future<void> skipBackward10Seconds() async {
    if (isFmMode) {
      await tunePreviousFmStation();
      return;
    }
    final target = player.position - const Duration(seconds: 10);
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> playNext() async {
    if (isFmMode) {
      await tuneNextFmStation();
    } else {
      await _advanceToNextTrack(withCrossfade: false);
    }
  }

  Future<void> playPrevious() async {
    if (isFmMode) {
      await tunePreviousFmStation();
      return;
    }
    if (playQueue.isEmpty) return;
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }
    _upNextInsertedCount = 0;
    if (currentIndex - 1 >= 0) {
      currentIndex--;
    } else {
      currentIndex = playQueue.length - 1;
    }
    await _loadImmediateOnPrimary();
  }

  void toggleShuffle() {
    isShuffle = !isShuffle;
    _upNextInsertedCount = 0;
    if (isShuffle && playQueue.length > 1) {
      final current = currentSong;
      playQueue.shuffle();
      if (current != null) {
        playQueue.removeWhere((s) => s.id == current.id);
        playQueue.insert(0, current);
        currentIndex = 0;
      }
    } else {
      final current = currentSong;
      playQueue = List.from(allSongs);
      if (current != null) {
        currentIndex = playQueue.indexWhere((s) => s.id == current.id);
      }
    }
    notifyListeners();
  }

  void toggleRepeat() {
    if (loopMode == LoopMode.off) {
      loopMode = LoopMode.all;
    } else if (loopMode == LoopMode.all) {
      loopMode = LoopMode.one;
    } else {
      loopMode = LoopMode.off;
    }
    notifyListeners();
  }
}
