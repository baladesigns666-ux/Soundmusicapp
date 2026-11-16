import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioController extends ChangeNotifier {
  AudioController._();
  static final AudioController instance = AudioController._();

  AudioPlayer _primaryPlayer = AudioPlayer();
  AudioPlayer _secondaryPlayer = AudioPlayer();

  final OnAudioQuery audioQuery = OnAudioQuery();

  List<SongModel> allSongs = [];
  List<AlbumModel> allAlbums = [];
  List<ArtistModel> allArtists = [];
  List<SongModel> playQueue = [];
  Set<int> likedSongIds = {};

  int currentIndex = -1;
  bool isPlaying = false;
  bool isShuffle = false;
  LoopMode loopMode = LoopMode.off;

  double crossfadeSeconds = 4.0;
  bool _isCrossfading = false;

  StreamSubscription<PlayerState>? _primaryStateSub;
  StreamSubscription<Duration>? _primaryPosSub;

  AudioPlayer get player => _primaryPlayer;

  SongModel? get currentSong =>
      (currentIndex >= 0 && currentIndex < playQueue.length)
          ? playQueue[currentIndex]
          : null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLikes = prefs.getStringList('liked_songs') ?? [];
    likedSongIds = savedLikes.map((e) => int.parse(e)).toSet();
    crossfadeSeconds = prefs.getDouble('crossfade_seconds') ?? 4.0;

    _attachPlayerListeners();
  }

  void _attachPlayerListeners() {
    _primaryStateSub?.cancel();
    _primaryPosSub?.cancel();

    _primaryStateSub = _primaryPlayer.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed && !_isCrossfading) {
        playNext();
      }
      notifyListeners();
    });

    _primaryPosSub = _primaryPlayer.positionStream.listen((position) {
      if (crossfadeSeconds <= 0 || _isCrossfading || !_primaryPlayer.playing) {
        return;
      }
      final total = _primaryPlayer.duration;
      if (total == null || total.inSeconds <= (crossfadeSeconds + 3)) return;

      final remainingMs = (total - position).inMilliseconds;
      final fadeWindowMs = (crossfadeSeconds * 1000).toInt();

      if (remainingMs > 0 && remainingMs <= fadeWindowMs) {
        _triggerCrossfadeToNext();
      }
    });
  }

  Future<void> setCrossfadeDuration(double seconds) async {
    crossfadeSeconds = seconds.clamp(0.0, 12.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('crossfade_seconds', crossfadeSeconds);
  }

  MediaItem _buildMediaItem(SongModel song) {
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Sound Music',
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: Uri.parse(
        'content://media/external/audio/media/${song.id}/albumart',
      ),
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

    currentIndex = idx;
    await _loadAndPlayCurrent();
  }

  Future<void> _loadAndPlayCurrent() async {
    final song = currentSong;
    if (song == null || song.uri == null) return;
    try {
      await _secondaryPlayer.stop();
      await _primaryPlayer.setVolume(1.0);
      await _primaryPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(song.uri!),
          tag: _buildMediaItem(song),
        ),
      );
      await _primaryPlayer.play();
      notifyListeners();
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  Future<void> _triggerCrossfadeToNext() async {
    if (_isCrossfading || playQueue.isEmpty) return;

    int nextIdx = currentIndex + 1;
    if (nextIdx >= playQueue.length) {
      if (loopMode == LoopMode.all) {
        nextIdx = 0;
      } else {
        return;
      }
    }

    if (loopMode == LoopMode.one) {
      nextIdx = currentIndex;
    }

    final nextSong = playQueue[nextIdx];
    if (nextSong.uri == null) return;

    _isCrossfading = true;
    notifyListeners();

    try {
      await _secondaryPlayer.setVolume(0.0);
      await _secondaryPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(nextSong.uri!),
          tag: _buildMediaItem(nextSong),
        ),
      );
      await _secondaryPlayer.play();

      const int steps = 20;
      final stepDuration = Duration(
        milliseconds: ((crossfadeSeconds * 1000) / steps).round().clamp(30, 600),
      );

      for (int i = 1; i <= steps; i++) {
        await Future.delayed(stepDuration);
        final progress = i / steps;
        await _primaryPlayer.setVolume((1.0 - progress).clamp(0.0, 1.0));
        await _secondaryPlayer.setVolume(progress.clamp(0.0, 1.0));
      }

      await _primaryPlayer.stop();
      await _primaryPlayer.setVolume(1.0);

      final temp = _primaryPlayer;
      _primaryPlayer = _secondaryPlayer;
      _secondaryPlayer = temp;

      currentIndex = nextIdx;
      _attachPlayerListeners();
    } catch (e) {
      debugPrint('Crossfade error: $e');
    } finally {
      _isCrossfading = false;
      notifyListeners();
    }
  }

  void addToPlayNext(SongModel song) {
    if (playQueue.isEmpty || currentIndex == -1) {
      playQueue = [song, ...allSongs.where((s) => s.id != song.id)];
      notifyListeners();
      return;
    }

    final existingIdx = playQueue.indexWhere((s) => s.id == song.id);
    if (existingIdx == currentIndex) return;

    if (existingIdx != -1) {
      playQueue.removeAt(existingIdx);
      if (existingIdx < currentIndex) {
        currentIndex--;
      }
    }

    final insertPosition = (currentIndex + 1).clamp(0, playQueue.length);
    playQueue.insert(insertPosition, song);
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
    if (_primaryPlayer.playing) {
      await _primaryPlayer.pause();
    } else {
      if (currentSong == null && allSongs.isNotEmpty) {
        await playSong(allSongs.first);
      } else {
        await _primaryPlayer.play();
      }
    }
    notifyListeners();
  }

  Future<void> skipForward10Seconds() async {
    final duration = _primaryPlayer.duration;
    if (duration == null) return;
    final target = _primaryPlayer.position + const Duration(seconds: 10);
    if (target >= duration) {
      await playNext();
    } else {
      await _primaryPlayer.seek(target);
    }
  }

  Future<void> skipBackward10Seconds() async {
    final target = _primaryPlayer.position - const Duration(seconds: 10);
    await _primaryPlayer.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> playNext() async {
    if (playQueue.isEmpty) return;
    if (loopMode == LoopMode.one) {
      await _primaryPlayer.seek(Duration.zero);
      await _primaryPlayer.play();
      return;
    }
    if (currentIndex + 1 < playQueue.length) {
      currentIndex++;
      await _loadAndPlayCurrent();
    } else if (loopMode == LoopMode.all) {
      currentIndex = 0;
      await _loadAndPlayCurrent();
    }
  }

  Future<void> playPrevious() async {
    if (playQueue.isEmpty) return;
    if (_primaryPlayer.position.inSeconds > 3) {
      await _primaryPlayer.seek(Duration.zero);
      return;
    }
    if (currentIndex - 1 >= 0) {
      currentIndex--;
      await _loadAndPlayCurrent();
    } else {
      currentIndex = playQueue.length - 1;
      await _loadAndPlayCurrent();
    }
  }

  void toggleShuffle() {
    isShuffle = !isShuffle;
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
