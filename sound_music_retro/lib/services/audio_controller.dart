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
  final double frequencyMhz;
  final String genre;
  final String streamUrl;
  final String backupUrl;

  const FmStation({
    required this.id,
    required this.name,
    required this.frequencyMhz,
    required this.genre,
    required this.streamUrl,
    required this.backupUrl,
  });

  String get frequencyLabel => '${frequencyMhz.toStringAsFixed(1)} MHz';
}

class AudioController extends ChangeNotifier {
  AudioController._();
  static final AudioController instance = AudioController._();

  // Primary player bound to just_audio_background (Lock Screen & Notification Bar)
  final AudioPlayer player = AudioPlayer();

  // Secondary tail player with handleInterruptions: false so outgoing & incoming tracks overlap cleanly
  final AudioPlayer _fadeOutPlayer = AudioPlayer(handleInterruptions: false);

  final OnAudioQuery audioQuery = OnAudioQuery();

  static const double minFmMhz = 88.0;
  static const double maxFmMhz = 108.0;

  // Live Playable FM Radio Stations spread across the 88.0 - 108.0 MHz Analog Band
  final List<FmStation> fmStations = const [
    FmStation(
      id: 'fm_suriyan',
      name: 'SURIYAN FM',
      frequencyMhz: 93.5,
      genre: 'Tamil Superhits',
      streamUrl: 'https://stream.zeno.fm/0r0xa792kwzuv',
      backupUrl: 'https://stream.zeno.fm/4d61y12021zuv',
    ),
    FmStation(
      id: 'fm_mirchi',
      name: 'RADIO MIRCHI',
      frequencyMhz: 98.3,
      genre: 'Non-Stop Kollywood',
      streamUrl: 'https://stream.zeno.fm/4d61y12021zuv',
      backupUrl: 'https://stream.zeno.fm/0r0xa792kwzuv',
    ),
    FmStation(
      id: 'fm_raja',
      name: 'RAJA MELODIES',
      frequencyMhz: 101.4,
      genre: '80s & 90s Maestro',
      streamUrl: 'https://stream.zeno.fm/2y96n36661zuv',
      backupUrl: 'https://stream.zeno.fm/0r0xa792kwzuv',
    ),
    FmStation(
      id: 'fm_chennai_air',
      name: 'CHENNAI AIR FM',
      frequencyMhz: 102.3,
      genre: 'All India Radio Live',
      streamUrl:
          'https://air.pc.cdn.bitgravity.com/air/live/pbaudio022/playlist.m3u8',
      backupUrl: 'https://stream.zeno.fm/4d61y12021zuv',
    ),
    FmStation(
      id: 'fm_lofi_night',
      name: 'VINYL LO-FI FM',
      frequencyMhz: 106.4,
      genre: 'Late Night Analog Chill',
      streamUrl: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
      backupUrl: 'https://stream.zeno.fm/2y96n36661zuv',
    ),
  ];

  double currentDialMhz = 98.3;
  FmStation? activeFmStation;
  bool isFmLoading = false;
  String? fmErrorMessage;

  List<SongModel> allSongs = [];
  List<AlbumModel> allAlbums = [];
  List<ArtistModel> allArtists = [];
  List<SongModel> playQueue = [];
  Set<int> likedSongIds = {};

  ConcatenatingAudioSource? _playlistSource;
  int _upNextInsertedCount = 0;

  int currentIndex = -1;
  bool isPlaying = false;
  bool isShuffle = false;
  LoopMode loopMode = LoopMode.off;

  double crossfadeSeconds = 4.0;
  bool _isCrossfading = false;
  int _crossfadeToken = 0;
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

    // Keep play/pause UI synchronized
    player.playingStream.listen((playing) {
      isPlaying = playing;
      if (playing) {
        isFmLoading = false;
      }
      notifyListeners();
    });

    // Keep currentIndex synchronized with native ConcatenatingAudioSource index
    // (Handles automatic track advance when a song finishes + Lock Screen Next/Prev!)
    player.currentIndexStream.listen((idx) {
      if (!isFmMode &&
          idx != null &&
          idx >= 0 &&
          idx < playQueue.length &&
          idx != currentIndex) {
        currentIndex = idx;
        if (_upNextInsertedCount > 0) {
          _upNextInsertedCount--;
        }
        notifyListeners();
      }
    });

    // Handle end of entire queue when loopMode == LoopMode.off
    player.processingStateStream.listen((procState) {
      if (procState == ProcessingState.ready) {
        isFmLoading = false;
        notifyListeners();
      } else if (procState == ProcessingState.completed &&
          !isFmMode &&
          !_isCrossfading &&
          playQueue.isNotEmpty) {
        // Wrap back to first song and pause or loop cleanly
        player.seek(Duration.zero, index: 0);
        if (loopMode == LoopMode.off) {
          player.pause();
        }
      }
    });

    // Position listener for True Overlapping Equal-Power Crossfade
    player.positionStream.listen((position) {
      if (isFmMode ||
          crossfadeSeconds <= 0 ||
          _isCrossfading ||
          !player.playing ||
          playQueue.length < 2) {
        return;
      }

      final total = player.duration;
      if (total == null || total.inSeconds <= (crossfadeSeconds + 3)) return;

      final remainingMs = (total - position).inMilliseconds;
      final fadeWindowMs = (crossfadeSeconds * 1000).toInt();

      if (remainingMs > 250 && remainingMs <= fadeWindowMs) {
        _triggerOverlappingCrossfade();
      }
    });
  }

  /// Move the analog tuning needle smoothly while dragging the dial
  void scrubFmDial(double targetMhz) {
    currentDialMhz = targetMhz.clamp(minFmMhz, maxFmMhz);
    notifyListeners();
  }

  /// Tune to the nearest FM station when releasing the analog dial
  Future<void> commitFmDialTune(double targetMhz) async {
    currentDialMhz = targetMhz.clamp(minFmMhz, maxFmMhz);
    FmStation nearest = fmStations.first;
    double bestDiff = (nearest.frequencyMhz - currentDialMhz).abs();

    for (final st in fmStations) {
      final diff = (st.frequencyMhz - currentDialMhz).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        nearest = st;
      }
    }

    currentDialMhz = nearest.frequencyMhz;
    await playFmStation(nearest);
  }

  /// Play Live FM Radio Stream (with automatic backup stream fallback)
  Future<void> playFmStation(FmStation station) async {
    _cancelCrossfade();
    fmErrorMessage = null;
    isFmLoading = true;
    activeFmStation = station;
    currentDialMhz = station.frequencyMhz;
    notifyListeners();

    final mediaItem = MediaItem(
      id: station.id,
      album: 'LIVE FM • ${station.frequencyLabel}',
      title: '${station.name} (${station.frequencyLabel})',
      artist: station.genre,
    );

    try {
      await _fadeOutPlayer.stop();
      await player.stop();
      await player.setVolume(1.0);
      await player.setLoopMode(LoopMode.off);

      await player.setAudioSource(
        AudioSource.uri(Uri.parse(station.streamUrl), tag: mediaItem),
      );
      await player.play();
    } catch (_) {
      // Fallback to backup stream URL if primary stream is unreachable
      try {
        await player.setAudioSource(
          AudioSource.uri(Uri.parse(station.backupUrl), tag: mediaItem),
        );
        await player.play();
      } catch (e) {
        fmErrorMessage =
            'SIGNAL WEAK ON ${station.frequencyLabel} - CHECK INTERNET';
        debugPrint('FM playback error: $e');
      }
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

  Future<AudioSource> _buildAudioSourceForSong(SongModel song) async {
    final artUri = await _resolveArtworkUri(song.id);
    final mediaItem = MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Sound Music',
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: artUri,
    );
    return AudioSource.uri(Uri.parse(song.uri!), tag: mediaItem);
  }

  Future<void> loadLocalLibrary() async {
    allSongs = await audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    allSongs = allSongs
        .where((s) => (s.duration ?? 0) > 15000 && s.uri != null)
        .toList();

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

  /// Loads the entire queue into a native ConcatenatingAudioSource so:
  /// - Auto-advance on song completion works 100% natively
  /// - Lock Screen & Notification Next/Previous buttons work natively
  /// - In-app Next/Previous buttons seek immediately with zero lag
  Future<void> playSong(SongModel song, {List<SongModel>? customList}) async {
    _cancelCrossfade();
    activeFmStation = null;
    fmErrorMessage = null;
    isFmLoading = false;

    if (customList != null && customList.isNotEmpty) {
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
    notifyListeners();

    try {
      await _fadeOutPlayer.stop();
      final sources = await Future.wait(
        playQueue.map((s) => _buildAudioSourceForSong(s)),
      );
      _playlistSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: sources,
      );

      await player.setVolume(1.0);
      await player.setLoopMode(loopMode);
      await player.setAudioSource(
        _playlistSource!,
        initialIndex: currentIndex,
        initialPosition: Duration.zero,
      );
      await player.play();
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  void _cancelCrossfade() {
    _crossfadeToken++;
    _isCrossfading = false;
    _fadeOutPlayer.stop();
    player.setVolume(1.0);
  }

  /// True Dual-Stream Overlapping Equal-Power Crossfade
  Future<void> _triggerOverlappingCrossfade() async {
    if (_isCrossfading || playQueue.length < 2) return;

    int nextIdx;
    if (loopMode == LoopMode.one) {
      nextIdx = currentIndex;
    } else if (currentIndex + 1 < playQueue.length) {
      nextIdx = currentIndex + 1;
    } else {
      nextIdx = 0;
    }

    final outgoingSong = currentSong;
    if (outgoingSong == null || outgoingSong.uri == null) return;

    _isCrossfading = true;
    final token = ++_crossfadeToken;

    try {
      final fadeDuration =
          Duration(milliseconds: (crossfadeSeconds * 1000).toInt());

      // Step 1: Load outgoing song tail into _fadeOutPlayer at exact current position
      await _fadeOutPlayer.stop();
      await _fadeOutPlayer.setVolume(1.0);
      await _fadeOutPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(outgoingSong.uri!)),
      );

      final handoffPos = player.position + const Duration(milliseconds: 50);
      await _fadeOutPlayer.seek(handoffPos);
      await _fadeOutPlayer.play();

      if (token != _crossfadeToken) return;

      // Step 2: Advance primary player to next song at 0.0 volume
      await player.setVolume(0.0);
      currentIndex = nextIdx;
      notifyListeners();

      if (_playlistSource != null && nextIdx < _playlistSource!.length) {
        await player.seek(Duration.zero, index: nextIdx);
      } else {
        await player.seekToNext();
      }
      if (!player.playing) {
        await player.play();
      }

      // Step 3: 30-step Equal-Power Sine/Cosine DJ Crossfade
      const int steps = 30;
      final stepMs =
          (fadeDuration.inMilliseconds / steps).round().clamp(25, 400);

      for (int i = 1; i <= steps; i++) {
        await Future.delayed(Duration(milliseconds: stepMs));
        if (token != _crossfadeToken) return;

        final t = i / steps;
        final outGain = math.cos(t * math.pi / 2).clamp(0.0, 1.0);
        final inGain = math.sin(t * math.pi / 2).clamp(0.0, 1.0);

        await _fadeOutPlayer.setVolume(outGain);
        await player.setVolume(inGain);
      }

      if (token == _crossfadeToken) {
        await player.setVolume(1.0);
        await _fadeOutPlayer.stop();
      }
    } catch (e) {
      debugPrint('Crossfade error: $e');
      await player.setVolume(1.0);
      await _fadeOutPlayer.stop();
    } finally {
      if (token == _crossfadeToken) {
        _isCrossfading = false;
      }
      notifyListeners();
    }
  }

  /// FIFO Play-Next Queue: 1st added song stays 1st, 2nd added song stays 2nd
  Future<void> addToPlayNext(SongModel song) async {
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
      if (_playlistSource != null && existingIdx < _playlistSource!.length) {
        await _playlistSource!.removeAt(existingIdx);
      }
      if (existingIdx < currentIndex) {
        currentIndex--;
      }
    }

    final insertPosition =
        (currentIndex + 1 + _upNextInsertedCount).clamp(0, playQueue.length);
    playQueue.insert(insertPosition, song);
    if (_playlistSource != null) {
      final src = await _buildAudioSourceForSong(song);
      await _playlistSource!.insert(insertPosition, src);
    }
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

  /// Immediate, guaranteed Next Track
  Future<void> playNext() async {
    if (isFmMode) {
      await tuneNextFmStation();
      return;
    }
    if (playQueue.isEmpty && allSongs.isNotEmpty) {
      await playSong(allSongs.first);
      return;
    }
    if (playQueue.isEmpty) return;

    _cancelCrossfade();

    if (_upNextInsertedCount > 0) {
      _upNextInsertedCount--;
    }

    final nextIdx =
        (currentIndex + 1 < playQueue.length) ? currentIndex + 1 : 0;
    currentIndex = nextIdx;
    notifyListeners();

    if (_playlistSource != null && nextIdx < _playlistSource!.length) {
      await player.seek(Duration.zero, index: nextIdx);
      if (!player.playing) {
        await player.play();
      }
    } else {
      await playSong(playQueue[nextIdx], customList: playQueue);
    }
  }

  /// Immediate, guaranteed Previous Track
  Future<void> playPrevious() async {
    if (isFmMode) {
      await tunePreviousFmStation();
      return;
    }
    if (playQueue.isEmpty && allSongs.isNotEmpty) {
      await playSong(allSongs.first);
      return;
    }
    if (playQueue.isEmpty) return;

    _cancelCrossfade();

    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }

    _upNextInsertedCount = 0;
    final prevIdx =
        (currentIndex - 1 >= 0) ? currentIndex - 1 : playQueue.length - 1;
    currentIndex = prevIdx;
    notifyListeners();

    if (_playlistSource != null && prevIdx < _playlistSource!.length) {
      await player.seek(Duration.zero, index: prevIdx);
      if (!player.playing) {
        await player.play();
      }
    } else {
      await playSong(playQueue[prevIdx], customList: playQueue);
    }
  }

  Future<void> toggleShuffle() async {
    isShuffle = !isShuffle;
    _upNextInsertedCount = 0;
    final current = currentSong;

    if (isShuffle && playQueue.length > 1) {
      playQueue.shuffle();
      if (current != null) {
        playQueue.removeWhere((s) => s.id == current.id);
        playQueue.insert(0, current);
        currentIndex = 0;
      }
    } else {
      playQueue = List.from(allSongs);
      if (current != null) {
        currentIndex = playQueue.indexWhere((s) => s.id == current.id);
      }
    }

    // Rebuild ConcatenatingAudioSource while preserving current playback position seamlessly
    if (!isFmMode && current != null && playQueue.isNotEmpty) {
      final pos = player.position;
      final wasPlaying = player.playing;
      final sources = await Future.wait(
        playQueue.map((s) => _buildAudioSourceForSong(s)),
      );
      _playlistSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: sources,
      );
      await player.setAudioSource(
        _playlistSource!,
        initialIndex: currentIndex.clamp(0, playQueue.length - 1),
        initialPosition: pos,
      );
      if (wasPlaying) {
        await player.play();
      }
    }

    notifyListeners();
  }

  Future<void> toggleRepeat() async {
    if (loopMode == LoopMode.off) {
      loopMode = LoopMode.all;
    } else if (loopMode == LoopMode.all) {
      loopMode = LoopMode.one;
    } else {
      loopMode = LoopMode.off;
    }
    await player.setLoopMode(loopMode);
    notifyListeners();
  }
}
