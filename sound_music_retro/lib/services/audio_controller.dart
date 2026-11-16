import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioController extends ChangeNotifier {
  AudioController._();
  static final AudioController instance = AudioController._();

  // Single primary player bound to just_audio_background (guarantees Lock Screen & Notification Bar controls!)
  final AudioPlayer player = AudioPlayer();
  // Dedicated crossfade fade-out tail player (plays decaying tail of outgoing track smoothly)
  final AudioPlayer _fadeOutPlayer = AudioPlayer();

  final OnAudioQuery audioQuery = OnAudioQuery();

  List<SongModel> allSongs = [];
  List<AlbumModel> allAlbums = [];
  List<ArtistModel> allArtists = [];
  List<SongModel> playQueue = [];
  Set<int> likedSongIds = {};

  // Track how many "Play Next" songs are queued sequentially after currentIndex
  int _upNextInsertedCount = 0;

  int currentIndex = -1;
  bool isPlaying = false;
  bool isShuffle = false;
  LoopMode loopMode = LoopMode.off;

  // Crossfade state (0 to 12 seconds, default 4s)
  double crossfadeSeconds = 4.0;
  bool _isTransitioning = false;
  String? _tempArtDir;

  SongModel? get currentSong =>
      (currentIndex >= 0 && currentIndex < playQueue.length)
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

    // Configure Android AudioSession for Music Playback & Notification Controls
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Handle track completion -> Automatically play next song
    player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed &&
          !_isTransitioning) {
        _advanceToNextTrack(withCrossfade: false);
      }
      notifyListeners();
    });

    // Monitor playback position to trigger smooth Crossfade into next song
    player.positionStream.listen((position) {
      if (crossfadeSeconds <= 0 ||
          _isTransitioning ||
          !player.playing ||
          playQueue.isEmpty) {
        return;
      }
      final total = player.duration;
      if (total == null || total.inSeconds <= (crossfadeSeconds + 3)) return;

      final remainingMs = (total - position).inMilliseconds;
      final fadeWindowMs = (crossfadeSeconds * 1000).toInt();

      if (remainingMs > 150 && remainingMs <= fadeWindowMs) {
        _advanceToNextTrack(withCrossfade: true);
      }
    });
  }

  Future<void> setCrossfadeDuration(double seconds) async {
    crossfadeSeconds = seconds.clamp(0.0, 12.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('crossfade_seconds', crossfadeSeconds);
  }

  /// Extracts real album artwork to a local file URI so Android Notification & Lock Screen display it reliably
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
    await _loadAndPlayOnPrimary(fadeInDuration: Duration.zero);
  }

  Future<void> _loadAndPlayOnPrimary({required Duration fadeInDuration}) async {
    final song = currentSong;
    if (song == null || song.uri == null) return;

    try {
      final mediaItem = await _buildMediaItem(song);
      final source = AudioSource.uri(
        Uri.parse(song.uri!),
        tag: mediaItem,
      );

      if (fadeInDuration > Duration.zero) {
        await player.setVolume(0.0);
        await player.setAudioSource(source);
        await player.play();

        const int steps = 20;
        final stepMs =
            (fadeInDuration.inMilliseconds / steps).round().clamp(30, 500);
        for (int i = 1; i <= steps; i++) {
          await Future.delayed(Duration(milliseconds: stepMs));
          await player.setVolume((i / steps).clamp(0.0, 1.0));
        }
        await player.setVolume(1.0);
      } else {
        await _fadeOutPlayer.stop();
        await player.setVolume(1.0);
        await player.setAudioSource(source);
        await player.play();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  /// Automatically advances to next song (supports seamless Crossfade + Notification update)
  Future<void> _advanceToNextTrack({required bool withCrossfade}) async {
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
      // Automatically wrap around to first song when queue ends
      nextIdx = 0;
    } else {
      return;
    }

    _isTransitioning = true;
    try {
      final outgoingSong = currentSong;
      final outgoingPos = player.position;

      // Consume one slot from FIFO Play-Next counter if active
      if (_upNextInsertedCount > 0) {
        _upNextInsertedCount--;
      }

      if (withCrossfade &&
          crossfadeSeconds > 0 &&
          outgoingSong != null &&
          outgoingSong.uri != null) {
        final fadeDuration =
            Duration(milliseconds: (crossfadeSeconds * 1000).toInt());

        // Start decaying tail of outgoing song on _fadeOutPlayer
        unawaited(_playFadeOutTail(
          uri: outgoingSong.uri!,
          startPosition: outgoingPos,
          fadeDuration: fadeDuration,
        ));

        // Immediately switch primary player (and Lock Screen / Notification Bar!) to next song with Fade-In
        currentIndex = nextIdx;
        await _loadAndPlayOnPrimary(fadeInDuration: fadeDuration);
      } else {
        currentIndex = nextIdx;
        await _loadAndPlayOnPrimary(fadeInDuration: Duration.zero);
      }
    } finally {
      _isTransitioning = false;
      notifyListeners();
    }
  }

  Future<void> _playFadeOutTail({
    required String uri,
    required Duration startPosition,
    required Duration fadeDuration,
  }) async {
    try {
      await _fadeOutPlayer.stop();
      await _fadeOutPlayer.setVolume(1.0);
      await _fadeOutPlayer.setAudioSource(AudioSource.uri(Uri.parse(uri)));
      await _fadeOutPlayer.seek(startPosition);
      await _fadeOutPlayer.play();

      const int steps = 20;
      final stepMs =
          (fadeDuration.inMilliseconds / steps).round().clamp(30, 500);
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(Duration(milliseconds: stepMs));
        final vol = (1.0 - (i / steps)).clamp(0.0, 1.0);
        await _fadeOutPlayer.setVolume(vol);
      }
      await _fadeOutPlayer.stop();
    } catch (_) {}
  }

  /// Swipe Right Action (FIFO Order):
  /// 1st added song stays 1st in Up-Next, 2nd added song stays 2nd in Up-Next!
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
      // If song was already inside the Up-Next block, decrement counter before re-appending to end of Up-Next
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
      if (currentSong == null && allSongs.isNotEmpty) {
        await playSong(allSongs.first);
      } else {
        await player.play();
      }
    }
    notifyListeners();
  }

  Future<void> skipForward10Seconds() async {
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
    final target = player.position - const Duration(seconds: 10);
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> playNext() async {
    await _advanceToNextTrack(withCrossfade: false);
  }

  Future<void> playPrevious() async {
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
    await _loadAndPlayOnPrimary(fadeInDuration: Duration.zero);
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
