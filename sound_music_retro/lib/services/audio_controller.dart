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

  // Dual DJ decks with handleInterruptions: false so they NEVER pause each other
  // when overlapping during crossfade!
  final AudioPlayer _deckA = AudioPlayer(handleInterruptions: false);
  final AudioPlayer _deckB = AudioPlayer(handleInterruptions: false);
  bool _isDeckAActive = true;

  /// Always points to the active foreground deck
  AudioPlayer get player => _isDeckAActive ? _deckA : _deckB;
  AudioPlayer get _standbyDeck => _isDeckAActive ? _deckB : _deckA;

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

  /// Tracks exact IDs of songs manually added by the user via "Play Next"
  final Set<int> userAddedQueueIds = {};
  int _upNextInsertedCount = 0;

  int currentIndex = -1;
  bool isPlaying = false;
  bool isShuffle = false;
  LoopMode loopMode = LoopMode.off;

  double crossfadeSeconds = 4.0;
  bool _isCrossfading = false;
  bool _isLoadingTrack = false;
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

  /// Reliable duration getter: uses active deck duration, falling back to SongModel metadata duration
  Duration get currentTrackDuration {
    if (isFmMode) return Duration.zero;
    final deckDur = player.duration;
    if (deckDur != null && deckDur.inMilliseconds > 1000) {
      return deckDur;
    }
    final metaMs = currentSong?.duration ?? 0;
    if (metaMs > 1000) {
      return Duration(milliseconds: metaMs);
    }
    return Duration.zero;
  }

  /// Resolves direct file:// URI when available so dual decks never hit Android MediaStore content:// lock
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
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        _deckA.pause();
        _deckB.pause();
      }
    });

    _bindDeckStreams(_deckA, isDeckA: true);
    _bindDeckStreams(_deckB, isDeckA: false);

    // 200ms Watchdog Timer: guarantees auto-advance & crossfade trigger reliably
    // across all screens (Home, Now Playing, Queue, Background)
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (isFmMode ||
          _isCrossfading ||
          _isLoadingTrack ||
          playQueue.isEmpty) {
        return;
      }

      if (player.processingState == ProcessingState.completed) {
        _advanceToNextTrack(withCrossfade: false);
        return;
      }

      if (player.playing) {
        final pos = player.position;
        _unifiedPositionController.add(pos);
        _checkAutoAdvanceOrCrossfade(pos);
      }
    });
  }

  void _bindDeckStreams(AudioPlayer deck, {required bool isDeckA}) {
    deck.playingStream.listen((playing) {
      if (_isDeckAActive != isDeckA) return;
      isPlaying = playing;
      if (playing) {
        isFmLoading = false;
      }
      notifyListeners();
    });

    deck.processingStateStream.listen((procState) {
      if (_isDeckAActive != isDeckA) return;
      if (procState == ProcessingState.ready) {
        isFmLoading = false;
        notifyListeners();
      } else if (procState == ProcessingState.completed &&
          !isFmMode &&
          !_isCrossfading &&
          !_isLoadingTrack &&
          playQueue.isNotEmpty) {
        _advanceToNextTrack(withCrossfade: false);
      }
    });

    deck.positionStream.listen((position) {
      if (_isDeckAActive != isDeckA) return;
      _unifiedPositionController.add(position);
      _checkAutoAdvanceOrCrossfade(position);
    });
  }

  void _checkAutoAdvanceOrCrossfade(Duration position) {
    if (isFmMode ||
        _isCrossfading ||
        _isLoadingTrack ||
        !player.playing ||
        playQueue.isEmpty) {
      return;
    }

    final total = currentTrackDuration;
    if (total.inMilliseconds <= 1500) return;

    final remainingMs = (total - position).inMilliseconds;

    // 1. Crossfade Window Trigger (Works on Now Playing Screen, Home Screen, & Background!)
    if (crossfadeSeconds > 0 &&
        playQueue.length > 1 &&
        total.inSeconds > (crossfadeSeconds + 2)) {
      final fadeWindowMs = (crossfadeSeconds * 1000).toInt();
      if (remainingMs > 250 && remainingMs <= fadeWindowMs) {
        _advanceToNextTrack(withCrossfade: true);
        return;
      }
    }

    // 2. End-of-Track Auto-Next Trigger (when crossfade is OFF or song is shorter than crossfade window)
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
      await _standbyDeck.stop();
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
      userAddedQueueIds.clear();
    } else if (playQueue.isEmpty) {
      playQueue = List.from(allSongs);
      userAddedQueueIds.clear();
    }

    int idx = playQueue.indexWhere((s) => s.id == song.id);
    if (idx == -1) {
      playQueue.insert(0, song);
      idx = 0;
    }

    _upNextInsertedCount = 0;
    currentIndex = idx;
    await _loadImmediateOnActiveDeck();
  }

  Future<void> _loadImmediateOnActiveDeck() async {
    final song = currentSong;
    if (song == null || song.uri == null) return;

    _isLoadingTrack = true;
    try {
      await _standbyDeck.stop();
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
      _isLoadingTrack = false;
    }
  }

  void _cancelCrossfade() {
    _crossfadeToken++;
    _isCrossfading = false;
    _standbyDeck.stop();
    player.setVolume(1.0);
  }

  Future<void> clearQueue() async {
    _cancelCrossfade();
    playQueue.clear();
    userAddedQueueIds.clear();
    currentIndex = -1;
    _upNextInsertedCount = 0;
    if (!isFmMode) {
      await _deckA.stop();
      await _deckB.stop();
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= playQueue.length) return;
    final removed = playQueue.removeAt(index);
    userAddedQueueIds.remove(removed.id);

    if (playQueue.isEmpty) {
      currentIndex = -1;
      _upNextInsertedCount = 0;
      _cancelCrossfade();
      _deckA.stop();
      _deckB.stop();
    } else if (index == currentIndex) {
      if (currentIndex >= playQueue.length) {
        currentIndex = 0;
      }
      _loadImmediateOnActiveDeck();
    } else if (index < currentIndex) {
      currentIndex--;
    }
    notifyListeners();
  }

  /// True Dual-Deck Overlapping Crossfade:
  /// Outgoing song keeps playing uninterrupted on `outgoingDeck` while fading 1.0 -> 0.0,
  /// and incoming next song starts simultaneously on `incomingDeck` while fading 0.0 -> 1.0!
  Future<void> _advanceToNextTrack({required bool withCrossfade}) async {
    if (isFmMode) {
      await tuneNextFmStation();
      return;
    }

    if (playQueue.isEmpty) {
      if (allSongs.isNotEmpty) {
        playQueue = List.from(allSongs);
      } else {
        return;
      }
    }

    if (_isCrossfading || _isLoadingTrack) {
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
      _isLoadingTrack = true;
      try {
        await player.seek(Duration.zero);
        await player.play();
      } finally {
        _isLoadingTrack = false;
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

    final incomingSong = playQueue[nextIdx];

    if (withCrossfade &&
        crossfadeSeconds > 0 &&
        incomingSong.uri != null) {
      _isCrossfading = true;
      _isLoadingTrack = true;
      final token = ++_crossfadeToken;

      final outgoingDeck = player;
      final incomingDeck = _standbyDeck;

      try {
        final fadeDuration =
            Duration(milliseconds: (crossfadeSeconds * 1000).toInt());
        final incomingUri = _playableUriForSong(incomingSong);

        // Prepare incoming next song on incomingDeck at 0.0 volume
        // NOTE: Do NOT pass MediaItem tag to incomingDeck during overlap so just_audio_background
        // never pauses outgoingDeck! We sync MediaItem tag cleanly once crossfade completes.
        await incomingDeck.stop();
        await incomingDeck.setVolume(0.0);
        await incomingDeck.setAudioSource(
          AudioSource.uri(incomingUri),
          initialPosition: Duration.zero,
        );

        if (token != _crossfadeToken) return;

        // Flip active deck pointer so Now Playing UI, progress slider & controls track incoming song
        _isDeckAActive = !_isDeckAActive;
        currentIndex = nextIdx;
        isPlaying = true;
        await incomingDeck.play();
        _isLoadingTrack = false;
        notifyListeners();

        // Smooth 40-step simultaneous volume ramp:
        // Outgoing playing song fades OUT (1.0 -> 0.0), Incoming next song fades IN (0.0 -> 1.0)
        const int steps = 40;
        final stepMs =
            (fadeDuration.inMilliseconds / steps).round().clamp(25, 300);

        for (int i = 1; i <= steps; i++) {
          await Future.delayed(Duration(milliseconds: stepMs));
          if (token != _crossfadeToken) return;

          final t = i / steps;
          final fadeOutVol = (1.0 - t).clamp(0.0, 1.0);
          final fadeInVol = t.clamp(0.0, 1.0);

          await outgoingDeck.setVolume(fadeOutVol);
          await incomingDeck.setVolume(fadeInVol);
        }

        if (token == _crossfadeToken) {
          await incomingDeck.setVolume(1.0);
          await outgoingDeck.stop();
        }
      } catch (e) {
        debugPrint('Crossfade error: $e');
        await incomingDeck.setVolume(1.0);
        await outgoingDeck.stop();
      } finally {
        _isLoadingTrack = false;
        if (token == _crossfadeToken) {
          _isCrossfading = false;
        }
        notifyListeners();
      }
    } else {
      currentIndex = nextIdx;
      await _loadImmediateOnActiveDeck();
    }
  }

  /// FIFO Play-Next Queue:
  /// - Only adds the exact song(s) selected by the user (never dumps the whole library into Play Queue!).
  /// - 1st added song plays 1st, 2nd added song plays 2nd.
  void addToPlayNext(SongModel song) {
    userAddedQueueIds.add(song.id);

    if (playQueue.isEmpty || currentIndex == -1) {
      playQueue = [song];
      currentIndex = 0;
      _upNextInsertedCount = 0;
      playSong(song, customList: playQueue);
      userAddedQueueIds.add(song.id);
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
      await _deckA.pause();
      await _deckB.pause();
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
    final duration = currentTrackDuration;
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
    await _loadImmediateOnActiveDeck();
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
