import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../core/audio_player_service.dart';
import '../../data/models/track_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/services/local_db_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService;
  final MusicRepository _repository;
  final LocalDbService _localDbService;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  TrackModel? _currentTrack;
  List<TrackModel> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  bool _isRepeat = false;
  final Set<String> _favorites = {};

  PlayerProvider({
    AudioPlayerService? audioService,
    MusicRepository? repository,
    LocalDbService? localDbService,
  })  : _audioService = audioService ?? AudioPlayerService(),
        _repository = repository ?? MusicRepository(),
        _localDbService = localDbService ?? LocalDbService() {
    _initStreams();
    _loadFavoritesFromDb();
  }

  TrackModel? get currentTrack => _currentTrack;
  List<TrackModel> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  Set<String> get favorites => _favorites;

  bool isFavorite(String trackId) => _favorites.contains(trackId);

  Future<void> _loadFavoritesFromDb() async {
    try {
      final favList = await _localDbService.getFavorites();
      _favorites.clear();
      _favorites.addAll(favList.map((t) => t.id));
      notifyListeners();
    } catch (e) {
      debugPrint('[PlayerProvider] Failed to load favorites from SQLite: $e');
    }
  }

  void _initStreams() {
    _playerStateSub = _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing && state.processingState != ProcessingState.completed;

      if (state.processingState == ProcessingState.ready || state.playing) {
        _isLoading = false;
      }

      if (state.processingState == ProcessingState.completed) {
        if (_isRepeat) {
          seek(Duration.zero);
          _audioService.resume();
        } else {
          next();
        }
      }

      notifyListeners();
    });

    _positionSub = _audioService.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _audioService.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  Future<void> playTrack(TrackModel track, {List<TrackModel>? newQueue}) async {
    _currentTrack = track;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Catat trek ke Recently Played di database lokal secara background
    _localDbService.addRecentlyPlayed(track).catchError((e) {
      debugPrint('[PlayerProvider] Error adding to recently played: $e');
    });

    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = List.from(newQueue);
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    } else if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    }

    try {
      final audioUri = await _repository.getAudioUrl(track);

      final mediaItem = MediaItem(
        id: track.id,
        album: track.album.isNotEmpty ? track.album : 'softcore',
        title: track.title,
        artist: track.artist,
        duration: track.duration != Duration.zero ? track.duration : null,
        artUri: track.artworkUrl.isNotEmpty ? Uri.tryParse(track.artworkUrl) : null,
      );

      await _audioService.playUri(mediaItem, audioUri);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat audio: $e';
      debugPrint('[PlayerProvider] playTrack error: $e');
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null) return;
    if (_isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.resume();
    }
  }

  Future<Duration?> seek(Duration position) async {
    _position = position;
    notifyListeners();
    await _audioService.seek(position);
    return _position;
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffle && _queue.length > 1) {
      final available = List.generate(_queue.length, (i) => i)..remove(_currentIndex);
      available.shuffle();
      _currentIndex = available.first;
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }

    await playTrack(_queue[_currentIndex]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await playTrack(_queue[_currentIndex]);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    _audioService.setLoopMode(_isRepeat ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  /// Menambah atau menghapus favorit dengan penyimpanan permanen SQLite
  Future<void> toggleFavorite(String trackId, [TrackModel? track]) async {
    final targetTrack = track ?? (_currentTrack?.id == trackId ? _currentTrack : null);

    if (_favorites.contains(trackId)) {
      _favorites.remove(trackId);
      notifyListeners();
      await _localDbService.removeFavorite(trackId);
    } else {
      _favorites.add(trackId);
      notifyListeners();
      if (targetTrack != null) {
        await _localDbService.saveFavorite(targetTrack);
      }
    }
  }

  Future<void> toggleFavoriteTrack(TrackModel track) async {
    await toggleFavorite(track.id, track);
  }

  Future<void> retryCurrentTrack() async {
    if (_currentTrack != null) {
      await playTrack(_currentTrack!);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }
}
