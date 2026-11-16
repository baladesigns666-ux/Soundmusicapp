import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioController extends ChangeNotifier {
  AudioController._();
  static final AudioController instance = AudioController._();

  final AudioPlayer player = AudioPlayer();
  final OnAudioQuery audioQuery = OnAudioQuery();

  List<SongModel> allSongs = [];
  List<SongModel> playQueue = [];
  Set<int> likedSongIds = {};

  int currentIndex = -1;
  bool isPlaying = false;
  bool isShuffle = false;
  LoopMode loopMode = LoopMode.off;

  SongModel? get currentSong =>
      (currentIndex >= 0 && currentIndex < playQueue.length)
          ? playQueue[currentIndex]
          : null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLikes = prefs.getStringList('liked_songs') ?? [];
    likedSongIds = savedLikes.map((e) => int.parse(e)).toSet();

    player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        playNext();
      }
      notifyListeners();
    });
  }

  Future<void> loadLocalSongs() async {
    allSongs = await audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    allSongs = allSongs.where((s) => (s.duration ?? 0) > 15000).toList();
    if (playQueue.isEmpty) {
      playQueue = List.from(allSongs);
    }
    notifyListeners();
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
      await player.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
      await player.play();
      notifyListeners();
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  /// Swipe Right Action: Inserts song immediately after the currently playing song
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

  /// Double-Tap Like Action
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

  /// Double-Tap Next Button Action: Seek forward 10 seconds
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

  /// Double-Tap Previous Button Action: Seek backward 10 seconds
  Future<void> skipBackward10Seconds() async {
    final target = player.position - const Duration(seconds: 10);
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> playNext() async {
    if (playQueue.isEmpty) return;
    if (loopMode == LoopMode.one) {
      await player.seek(Duration.zero);
      await player.play();
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
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
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
