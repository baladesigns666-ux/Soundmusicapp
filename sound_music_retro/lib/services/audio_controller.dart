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

  // Primary player handles background media notification & active playback
  final AudioPlayer player = AudioPlayer();

  // Dedicated secondary fade-out player (bypasses just_audio_background MediaItem tag
  // so Android ExoPlayer never blocks simultaneous two-player playback!)
  final AudioPlayer _fadeOutPlayer = AudioPlayer(handleInterruptions: false);

  final OnAudioQuery audioQuery = OnAudioQuery();

  static const double minFmMhz = 87.5;
  static const double maxFmMhz = 108.0;

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

  int _upNextInsertedCount = 0;

  int currentIndex = -1;
  bool isPlaying = false;
  bool isShuffle = false;
  LoopMode loopMode = LoopMode.off;

  double crossfadeSeconds = 4.0;
  bool _isCrossfading = false;
  bool _isTransitioning = false;
  int _crossfadeToken = 0;
  Timer? _watchdogTimer;
  String? _tempArtDir;

  final StreamController<Duration> _unifiedPositionController =
      StreamController<Duration>.broadcast();
  Stream<Duration> get activePositionStream => _unifiedPositionController.stream;

  bool get isFmMode => activeFmStation != null;

  SongModel? get currentSong =>
      (!isFmMode && currentIndex >= 0 && currentIndex < playQueue.length)
          ? playQueue[currentIndex]
          : null;

  /// Reliable duration getter: falls back to SongModel metadata duration if ExoPlayer returns null
  Duration _effectiveDuration(SongModel? song) {
    final playerDur = player.duration;
    if (playerDur != null && playerDur.inMilliseconds > 1000) {
      return playerDur;
    }
    final metaMs = song?.duration ?? 0;
    if (metaMs > 1000) {
      return Duration(milliseconds: metaMs);
    }
    return Duration.zero;
  }

  /// Resolves a local file URI (`file:///...`) so both primary & secondary players
  /// can read the audio file simultaneously without Android MediaStore content:// lock conflicts!
  Uri _playableUriForSong(SongModel song) {
    final dataPath = song.data;
    if (dataPath.isNotEmpty) {
      final f = File(dataPath);
      if (f.existsSync()) {
        return Uri.file(dataPath);
      }
    }
    return Uri.parse(song.uri!);
  }

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

    player.playingStream.listen((playing) {
      isPlaying = playing;
      if (playing) {
        isFmLoading = false;
      }
      notifyListeners();
    });

    // Listener 1: Immediate completion trigger
    player.processingStateStream.listen((procState) {
      if (procState == ProcessingState.ready) {
        isFmLoading = false;
        notifyListeners();
      } else if (procState == ProcessingState.completed &&
          !isFmMode &&
          !_isCrossfading &&
          !_isTransitioning &&
          playQueue.isNotEmpty) {
        _advanceToNextTrack(withCrossfade: false);
      }
    });

    // Listener 2: High-frequency position stream for crossfade window & completion
    player.positionStream.listen((position) {
      _unifiedPositionController.add(position);
      _evaluateTrackProgress(position);
    });

    // Listener 3: 250ms Watchdog Timer (guarantees auto-next & crossfade even if stream throttles)
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (isFmMode ||
          _isCrossfading ||
          _isTransitioning ||
          playQueue.isEmpty) {
        return;
      }

      if (player.processingState == ProcessingState.completed) {
        _advanceToNextTrack(withCrossfade: false);
        return;
      }

      if (player.playing) {
        _evaluateTrackProgress(player.position);
      }
    });
  }

  void _evaluateTrackProgress(Duration position) {
    if (isFmMode ||
        _isCrossfading ||
        _isTransitioning ||
        !player.playing ||
        playQueue.isEmpty) {
      return;
    }

    final total = _effectiveDuration(currentSong);
    if (total.inMilliseconds <= 1500) return;

    final remainingMs = (total - position).inMilliseconds;

    // Trigger Crossfade when entering the crossfade window before song ends
    if (crossfadeSeconds > 0 &&
        playQueue.length > 1 &&
        total.inSeconds > (crossfadeSeconds + 2)) {
      final fadeWindowMs = (crossfadeSeconds * 1000).toInt();
      if (remainingMs > 250 && remainingMs <= fadeWindowMs) {
        _advanceToNextTrack(withCrossfade: true);
        return;
      }
    }

    // Automatic next song trigger right at track end
    if (remainingMs <= 220) {
      _advanceToNextTrack(withCrossfade: false);
    }
  }

  void scrubFmDial(double targetMhz) {
    final stepped = ((targetMhz.clamp(minFmMhz, maxFmMhz)) * 10).round() / 10.0;
    currentDialMhz = stepped;
    notifyListeners();
  }

  Future<void> tuneManualFrequency(double targetMhz) async {
    final exactMhz =
        ((targetMhz.clamp(minFmMhz, maxFmMhz)) * 10).round() / 10.0;
    currentDialMhz = exactMhz;

    FmStation carrier = fmStations.first;
    double bestDiff = (carrier.frequencyMhz - exactMhz).abs();
    for (final st in fmStations) {
      final diff = (st.frequencyMhz - exactMhz).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        carrier = st;
      }
    }

    final isExactStation = bestDiff <= 0.3;
    final tunedStation = FmStation(
      id: 'fm_${exactMhz.toStringAsFixed(1)}',
      name: isExactStation
          ? carrier.name
          : 'FM ${exactMhz.toStringAsFixed(1)} BAND',
      frequencyMhz: exactMhz,
      genre: isExactStation ? carrier.genre : 'Manual Tuned Frequency',
      streamUrl: carrier.streamUrl,
      backupUrl: carrier.backupUrl,
    );

    await playFmStation(tunedStation, preserveExactDialMhz: true);
  }

  Future<void> playFmStation(
    FmStation station, {
    bool preserveExactDialMhz = false,
  }) async {
    _cancelCrossfade();
    fmErrorMessage = null;
    isFmLoading = true;
    activeFmStation = station;
    if (!preserveExactDialMhz) {
      currentDialMhz = station.frequencyMhz;
    }
    notifyListeners();

    final freqStr = '${currentDialMhz.toStringAsFixed(1)} MHz';
    final mediaItem = MediaItem(
      id: station.id,
      album: 'LIVE FM • $freqStr',
      title: '${station.name} ($freqStr)',
      artist: station.genre,
    );

    try {
      await _fadeOutPlayer.stop();
      await player.stop();
      await player.setVolume(1.0);

      await player.setAudioSource(
        AudioSource.uri(Uri.parse(station.streamUrl), tag: mediaItem),
      );
      await player.play();
    } catch (_) {
      try {
        await player.setAudioSource(
          AudioSource.uri(Uri.parse(station.backupUrl), tag: mediaItem),
        );
        await player.play();
      } catch (e) {
        fmErrorMessage = 'SIGNAL WEAK ON $freqStr - CHECK INTERNET';
        debugPrint('FM playback error: $e');
      }
    } finally {
      isFmLoading = false;
      notifyListeners();
    }
  }

  Future<void> stepFmFrequency(double deltaMhz) async {
    await tuneManualFrequency(currentDialMhz + deltaMhz);
  }

  Future<void> tuneNextFmStation() async {
    if (fmStations.isEmpty) return;
    if (activeFmStation == null) {
      await playFmStation(fmStations.first);
      return;
    }
    final idx = fmStations.indexWhere(
      (s) => (s.frequencyMhz - currentDialMhz).abs() < 0.2,
    );
    final nextIdx = idx == -1 ? 0 : (idx + 1) % fmStations.length;
    await playFmStation(fmStations[nextIdx]);
  }

  Future<void> tunePreviousFmStation() async {
    if (fmStations.isEmpty) return;
    if (activeFmStation == null) {
      await playFmStation(fmStations.first);
      return;
    }
    final idx = fmStations.indexWhere(
      (s) => (s.frequencyMhz - currentDialMhz).abs() < 0.2,
    );
    final prevIdx = idx == -1
        ? fmStations.length - 1
        : (idx - 1 + fmStations.length) % fmStations.length;
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
    await _loadImmediateOnPrimary();
  }

  Future<void> _loadImmediateOnPrimary() async {
    final song = currentSong;
    if (song == null || song.uri == null) return;

    _isTransitioning = true;
    try {
      await _fadeOutPlayer.stop();
      final mediaItem = await _buildMediaItem(song);
      final playableUri = _playableUriForSong(song);

      await player.setVolume(1.0);
      await player.setAudioSource(
        AudioSource.uri(playableUri, tag: mediaItem),
      );
      await player.seek(Duration.zero);
      await player.play();
      notifyListeners();
    } catch (e) {
      debugPrint('Playback error: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  void _cancelCrossfade() {
    _crossfadeToken++;
    _isCrossfading = false;
    _fadeOutPlayer.stop();
    player.setVolume(1.0);
  }

  Future<void> clearQueue() async {
    _cancelCrossfade();
    playQueue.clear();
    currentIndex = -1;
    _upNextInsertedCount = 0;
    if (!isFmMode) {
      await player.stop();
      await _fadeOutPlayer.stop();
    }
    notifyListeners();
  }

  /// True Crossfade + Guaranteed Automatic Next Song:
  /// 1. Outgoing playing song is handed off to `_fadeOutPlayer` (no MediaItem tag -> bypasses
  ///    just_audio_background lock) and smoothly fades OUT (1.0 -> 0.0).
  /// 2. Incoming next song starts immediately on primary `player` at volume 0.0 and smoothly
  ///    fades IN (0.0 -> 1.0) simultaneously!
  Future<void> _advanceToNextTrack({required bool withCrossfade}) async {
    if (isFmMode) {
      await tuneNextFmStation();
      return;
    }

    if (playQueue.isEmpty && allSongs.isNotEmpty) {
      playQueue = List.from(allSongs);
    }
    if (playQueue.isEmpty) return;

    if (_isCrossfading || _isTransitioning) {
      if (!withCrossfade) {
        _cancelCrossfade();
      } else {
        return;
      }
    }

    if (currentIndex < 0 || currentIndex >= playQueue.length) {
      currentIndex = 0;
    }

    int nextIdx;
    if (loopMode == LoopMode.one && !withCrossfade) {
      _isTransitioning = true;
      try {
        await player.seek(Duration.zero);
        await player.play();
      } finally {
        _isTransitioning = false;
      }
      return;
    } else if (loopMode == LoopMode.one && withCrossfade) {
      nextIdx = currentIndex;
    } else if (currentIndex + 1 < playQueue.length) {
      nextIdx = currentIndex + 1;
    } else {
      nextIdx = 0;
    }

    if (_upNextInsertedCount > 0) {
      _upNextInsertedCount--;
    }

    final outgoingSong = currentSong;
    final incomingSong = playQueue[nextIdx];

    if (withCrossfade &&
        crossfadeSeconds > 0 &&
        outgoingSong != null &&
        outgoingSong.uri != null &&
        incomingSong.uri != null) {
      _isCrossfading = true;
      _isTransitioning = true;
      final token = ++_crossfadeToken;

      try {
        final fadeDuration =
            Duration(milliseconds: (crossfadeSeconds * 1000).toInt());
        final outgoingUri = _playableUriForSong(outgoingSong);
        final incomingUri = _playableUriForSong(incomingSong);
        final handoffPos = player.position;

        // 1. Start outgoing playing song on _fadeOutPlayer at 100% volume from exact handoffPos
        await _fadeOutPlayer.stop();
        await _fadeOutPlayer.setVolume(1.0);
        await _fadeOutPlayer.setAudioSource(
          AudioSource.uri(outgoingUri),
          initialPosition: handoffPos,
        );
        await _fadeOutPlayer.play();

        if (token != _crossfadeToken) return;

        // 2. Switch primary player to incoming next song at 0% volume & update UI immediately
        currentIndex = nextIdx;
        isPlaying = true;
        notifyListeners();

        final nextMediaItem = await _buildMediaItem(incomingSong);
        await player.setVolume(0.0);
        await player.setAudioSource(
          AudioSource.uri(incomingUri, tag: nextMediaItem),
          initialPosition: Duration.zero,
        );
        await player.play();
        _isTransitioning = false;

        // 3. Smooth 40-step simultaneous volume ramp:
        //    Playing song fades OUT (1.0 -> 0.0), Next song fades IN (0.0 -> 1.0)
        const int steps = 40;
        final stepMs =
            (fadeDuration.inMilliseconds / steps).round().clamp(25, 300);

        for (int i = 1; i <= steps; i++) {
          await Future.delayed(Duration(milliseconds: stepMs));
          if (token != _crossfadeToken) return;

          final t = i / steps;
          final fadeOutVol = (1.0 - t).clamp(0.0, 1.0);
          final fadeInVol = t.clamp(0.0, 1.0);

          await _fadeOutPlayer.setVolume(fadeOutVol);
          await player.setVolume(fadeInVol);
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
        _isTransitioning = false;
        if (token == _crossfadeToken) {
          _isCrossfading = false;
        }
        notifyListeners();
      }
    } else {
      currentIndex = nextIdx;
      await _loadImmediateOnPrimary();
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
    final duration = _effectiveDuration(currentSong);
    if (duration == Duration.zero) return;
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
      return;
    }
    await _advanceToNextTrack(withCrossfade: false);
  }

  Future<void> playPrevious() async {
    if (isFmMode) {
      await tunePreviousFmStation();
      return;
    }
    if (playQueue.isEmpty && allSongs.isNotEmpty) {
      playQueue = List.from(allSongs);
    }
    if (playQueue.isEmpty) return;

    _cancelCrossfade();

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
