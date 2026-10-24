# FULL CODE INSPECTION & ANDROID NATIVE AUDIT REPORT (UPDATED)

Dokumen ini berisi kode sumber mentah lengkap (**100% UTUH, TANPA RINGKASAN, TANPA POTONGAN**) dari seluruh komponen pemutar audio dan konfigurasi native Android di repositori Softcore setelah perbaikan 5 bug fatal diterapkan.

---

## 1. `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>

    <application
        android:label="softcore"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

        <service android:name="com.ryanheise.audioservice.AudioService"
                 android:foregroundServiceType="mediaPlayback"
                 android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
                  android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

---

## 2. `android/app/src/main/kotlin/com/softcore/softcore/MainActivity.kt`

```kotlin
package com.softcore.softcore

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity()
```

---

## 3. `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'core/local_audio_proxy.dart';
import 'core/theme.dart';
import 'data/repositories/music_repository.dart';
import 'data/services/local_db_service.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: ${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  };

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.softcore.audio.channel',
      androidNotificationChannelName: 'Softcore Playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('JustAudioBackground init error: $e');
  }

  // Inisialisasi In-App Local Audio Proxy untuk pemutaran langsung bebas throttling
  try {
    await LocalAudioProxy().start();
  } catch (e) {
    debugPrint('LocalAudioProxy start error: $e');
  }

  runApp(const SoftcoreApp());
}

class SoftcoreApp extends StatelessWidget {
  const SoftcoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalDbService>.value(value: LocalDbService()),
        Provider<MusicRepository>.value(value: MusicRepository()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: MaterialApp(
        title: 'softcore',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}
```

---

## 4. `lib/core/audio_player_service.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioPlayerService {
  AudioPlayerService._internal() {
    // Tangkap error langsung dari playbackEventStream ExoPlayer
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('[AudioPlayerService] PlaybackEvent error caught: $e');
      },
    );
  }

  static final AudioPlayerService _instance = AudioPlayerService._internal();

  factory AudioPlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  /// Memutar audio dari URI dengan penanganan stop(), timeout 15 detik, dan logging komprehensif
  Future<void> playUri(MediaItem item, Uri streamUri) async {
    debugPrint('[AudioPlayerService] 1/3 Resolving URL & preparing playback for: "${item.title}" by ${item.artist} -> $streamUri');

    try {
      // 1. Hentikan pemutaran sebelumnya untuk mencegah race condition atau overlapping
      await _player.stop();

      // 2. Set AudioSource bersih
      debugPrint('[AudioPlayerService] 2/3 Setting AudioSource...');
      final audioSource = AudioSource.uri(
        streamUri,
        tag: item,
      );

      // Gunakan timeout 15 detik pada setAudioSource agar ExoPlayer tidak hang selamanya jika stream bermasalah
      await _player
          .setAudioSource(audioSource)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Audio source loading timed out after 15 seconds: $streamUri'),
          );

      // 3. Mulai playback tanpa await agar Future tidak tertahan sampai akhir lagu
      debugPrint('[AudioPlayerService] 3/3 Starting playback...');
      unawaited(_player.play());
      debugPrint('[AudioPlayerService] Playback triggered successfully for "${item.title}"');
    } catch (e, stack) {
      debugPrint('[AudioPlayerService] Error loading or playing audio: $e\n$stack');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error pausing: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error resuming: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error stopping: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[AudioPlayerService] Error seeking: $e');
    }
  }

  Future<void> setLoopMode(LoopMode loopMode) async {
    try {
      await _player.setLoopMode(loopMode);
    } catch (e) {
      debugPrint('[AudioPlayerService] Error setting loop mode: $e');
    }
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    try {
      await _player.setShuffleModeEnabled(enabled);
    } catch (e) {
      debugPrint('[AudioPlayerService] Error setting shuffle mode: $e');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
```

---

## 5. `lib/presentation/providers/player_provider.dart`

```dart
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
```

---

## 6. `lib/data/repositories/music_repository.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/local_audio_proxy.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/track_model.dart';
import '../services/audiodb_service.dart';
import '../services/invidious_service.dart';
import '../services/saavn_service.dart';
import '../services/yt_service.dart';

class MusicRepository {
  static final MusicRepository _instance = MusicRepository._internal();

  final InvidiousService _invidiousService;
  final YtService _ytService;
  final AudioDbService _audioDbService;
  final SaavnService _saavnService;

  MusicRepository._internal({
    InvidiousService? invidiousService,
    YtService? ytService,
    AudioDbService? audioDbService,
    SaavnService? saavnService,
  })  : _invidiousService = invidiousService ?? InvidiousService(),
        _ytService = ytService ?? YtService(),
        _audioDbService = audioDbService ?? AudioDbService(),
        _saavnService = saavnService ?? SaavnService();

  factory MusicRepository({
    InvidiousService? invidiousService,
    YtService? ytService,
    AudioDbService? audioDbService,
    SaavnService? saavnService,
  }) {
    return _instance;
  }

  /// Mengambil daftar lagu trending barat dengan fallback berlapis
  Future<List<TrackModel>> getTrending() async {
    try {
      // 1. Coba pencarian curated via Invidious
      final results = await _invidiousService.searchTracks('The Weeknd Billie Eilish Lana Del Rey', limit: 25);
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('[MusicRepository] Invidious getTrending failed: $e. Falling back to YtService.');
    }

    try {
      // 2. Fallback ke YtService curated
      final curatedTracks = await _ytService.getCuratedWesternTrending();
      if (curatedTracks.isNotEmpty) return curatedTracks;
      return await _ytService.searchTracks('The Weeknd The Neighbourhood Billie Eilish Audio');
    } catch (e) {
      debugPrint('[MusicRepository] YtService getTrending fallback failed: $e');
      return [];
    }
  }

  /// Mengambil daftar album artis via TheAudioDB
  Future<List<AlbumModel>> getArtistAlbums(String artistName) async {
    try {
      return await _audioDbService.getArtistAlbums(artistName);
    } catch (_) {
      return [];
    }
  }

  /// Carian lagu: Invidious REST API (Primer) -> YtService (Fallback)
  Future<List<TrackModel>> search(String query) async {
    final sanitized = query.trim();
    if (sanitized.isEmpty) return [];

    try {
      // 1. Coba Invidious Service
      final results = await _invidiousService.searchTracks(sanitized);
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('[MusicRepository] Invidious search failed: $e. Falling back to YtService.');
    }

    try {
      // 2. Fallback ke YtService
      return await _ytService.searchTracks(sanitized);
    } catch (e) {
      debugPrint('[MusicRepository] YtService search fallback failed: $e');
      return [];
    }
  }

  /// Resolusi URL audio: Saavn Direct Akamai CDN (Primer) -> LocalAudioProxy In-Memory (Fallback YouTube)
  Future<Uri> getAudioUrl(TrackModel track) async {
    // 1. Coba streaming langsung dari Akamai CDN JioSaavn (bebas proxy, bebas IP/cipher YouTube)
    try {
      final saavnUrl = await _saavnService.getAudioUrl(track.title, track.artist);
      if (saavnUrl != null && saavnUrl.isNotEmpty) {
        debugPrint('[MusicRepository] Serving ultra-fast direct Akamai CDN stream from JioSaavn: $saavnUrl');
        return Uri.parse(saavnUrl);
      }
    } catch (e) {
      debugPrint('[MusicRepository] SaavnService failed: $e, falling back to YouTube.');
    }

    // 2. Fallback ke YouTube via In-Memory LocalAudioProxy (.m4a RAM buffer)
    try {
      if (!LocalAudioProxy().isRunning) {
        await LocalAudioProxy().start();
      }
      final localUri = LocalAudioProxy().getProxyUrl(track.youtubeVideoId);
      debugPrint('[MusicRepository] Serving audio stream via LocalAudioProxy RAM buffer: $localUri');
      return localUri;
    } catch (e) {
      debugPrint('[MusicRepository] LocalAudioProxy error, trying direct YtService: $e');
      return await _ytService.resolveStreamUrl(track.youtubeVideoId);
    }
  }

  /// Helper untuk resolusi berdasarkan videoId YouTube langsung
  Future<Uri> getAudioUrlByVideoId(String videoId) async {
    if (!LocalAudioProxy().isRunning) {
      await LocalAudioProxy().start();
    }
    return LocalAudioProxy().getProxyUrl(videoId);
  }

  /// Mendapatkan detail artis via TheAudioDB
  Future<ArtistModel?> getArtistDetails(String artistName) async {
    try {
      return await _audioDbService.getArtist(artistName);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _ytService.dispose();
  }
}
```

---

## 7. File Service Audio yang Aktif

### 7.1. `lib/data/services/saavn_service.dart`

```dart
import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SaavnService {
  static final SaavnService _instance = SaavnService._internal();
  factory SaavnService() => _instance;

  final Dio _dio;
  final Map<String, String> _cache = {};

  // DES Secret Key untuk enkripsi URL JioSaavn
  static final List<int> _desKey = utf8.encode('38346591');

  SaavnService._internal({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                  'Accept': 'application/json, text/plain, */*',
                },
              ),
            );

  /// Membersihkan judul lagu dari teks pengotor YouTube untuk meningkatkan akurasi pencarian
  String _cleanQuery(String title, String artist) {
    var cleanedTitle = title
        .replaceAll(RegExp(r'\((official|video|audio|lyrics?|feat\.?|ft\.?).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(official|video|audio|lyrics?|feat\.?|ft\.?).*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(official audio|official video|lyric video|music video)\b', caseSensitive: false), '')
        .trim();

    var cleanedArtist = artist
        .replaceAll(RegExp(r' - Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bVEVO\b', caseSensitive: false), '')
        .trim();

    if (cleanedArtist.isNotEmpty && !cleanedTitle.toLowerCase().contains(cleanedArtist.toLowerCase())) {
      return '$cleanedTitle $cleanedArtist'.trim();
    }
    return cleanedTitle;
  }

  /// Mendekripsi `encrypted_media_url` dari JioSaavn menggunakan DES-ECB
  String? _decryptMediaUrl(String encryptedUrl) {
    try {
      final des = DES(key: _desKey, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
      final cipherBytes = base64.decode(encryptedUrl.trim());
      final decryptedBytes = des.decrypt(cipherBytes);
      final decryptedUrl = utf8.decode(decryptedBytes).trim();

      if (decryptedUrl.startsWith('http://') || decryptedUrl.startsWith('https://')) {
        // Ganti bitrate ke kualitas terbaik (320kbps atau 160kbps)
        return decryptedUrl
            .replaceAll('_96.mp4', '_320.mp4')
            .replaceAll('_48.mp4', '_320.mp4')
            .replaceAll('http://', 'https://');
      }
      return null;
    } catch (e) {
      debugPrint('[SaavnService] Failed to decrypt media URL: $e');
      return null;
    }
  }

  /// Mencari lagu di JioSaavn dan mengembalikan direct Akamai CDN URL
  Future<String?> getAudioUrl(String title, String artist) async {
    final cacheKey = '${title.toLowerCase()}_${artist.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[SaavnService] Cache hit for "$cacheKey" -> ${_cache[cacheKey]}');
      return _cache[cacheKey];
    }

    final query = _cleanQuery(title, artist);
    debugPrint('[SaavnService] Resolving high-speed stream for query: "$query"');

    // 1. Coba Public Mirrors terlebih dahulu (bebas blokir ISP di Asia Tenggara)
    try {
      final mirrorUrl = await _resolveFromMirrors(query);
      if (mirrorUrl != null) {
        _cache[cacheKey] = mirrorUrl;
        debugPrint('[SaavnService] Successfully resolved via Mirror: $mirrorUrl');
        return mirrorUrl;
      }
    } catch (e) {
      debugPrint('[SaavnService] Mirror resolve error: $e');
    }

    // 2. Fallback ke Direct Official JioSaavn Search API
    try {
      final directUrl = await _resolveDirectSaavn(query);
      if (directUrl != null) {
        _cache[cacheKey] = directUrl;
        debugPrint('[SaavnService] Successfully resolved direct CDN URL: $directUrl');
        return directUrl;
      }
    } catch (e) {
      debugPrint('[SaavnService] Direct JioSaavn search error: $e');
    }

    // 3. Coba query hanya dengan judul lagu jika query gabungan gagal
    if (query != title) {
      try {
        final directUrl = await _resolveDirectSaavn(title.trim());
        if (directUrl != null) {
          _cache[cacheKey] = directUrl;
          debugPrint('[SaavnService] Successfully resolved by title: $directUrl');
          return directUrl;
        }
      } catch (_) {}
    }

    debugPrint('[SaavnService] Song not found on Saavn, fallback to YouTube.');
    return null;
  }

  /// Resolusi via mirror publik tidak resmi
  Future<String?> _resolveFromMirrors(String query) async {
    final mirrorEndpoints = [
      'https://saavn.dev/api/search/songs?query=${Uri.encodeComponent(query)}',
      'https://jiosaavn-api-privatecvc2.vercel.app/search/songs?query=${Uri.encodeComponent(query)}',
    ];

    for (final endpoint in mirrorEndpoints) {
      try {
        final resp = await _dio.get(endpoint);
        final data = resp.data;
        if (data is Map && data['data'] != null) {
          final songs = data['data']['results'] ?? data['data'];
          if (songs is List && songs.isNotEmpty) {
            final first = songs.first;
            final downloadUrl = first['downloadUrl'];
            if (downloadUrl is List && downloadUrl.isNotEmpty) {
              final highest = downloadUrl.last;
              final link = highest['link'] ?? highest['url'];
              if (link != null) {
                var strLink = link.toString().trim();
                if (strLink.startsWith('http://')) {
                  strLink = strLink.replaceFirst('http://', 'https://');
                }
                if (strLink.startsWith('https://')) {
                  return strLink;
                }
              }
            }
          }
        }
      } catch (_) {
        // Coba mirror berikutnya
      }
    }
    return null;
  }

  /// Resolusi menggunakan endpoint resmi internal JioSaavn (Direct)
  Future<String?> _resolveDirectSaavn(String query) async {
    final uri = Uri.https('www.jiosaavn.com', '/api.php', {
      '__call': 'search.getResults',
      '_format': 'json',
      '_marker': '0',
      'n': '5',
      'p': '1',
      'q': query,
    });

    final response = await _dio.getUri(uri);
    final data = response.data;

    Map<String, dynamic>? jsonMap;
    if (data is Map<String, dynamic>) {
      jsonMap = data;
    } else if (data is String) {
      try {
        jsonMap = json.decode(data) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }

    if (jsonMap == null) return null;

    final results = jsonMap['results'];
    if (results is List && results.isNotEmpty) {
      for (final item in results) {
        if (item is Map) {
          final encUrl = item['encrypted_media_url']?.toString();
          if (encUrl != null && encUrl.isNotEmpty) {
            final decrypted = _decryptMediaUrl(encUrl);
            if (decrypted != null) {
              return decrypted;
            }
          }
        }
      }
    }

    return null;
  }

  void clearCache() {
    _cache.clear();
  }
}
```

### 7.2. `lib/core/local_audio_proxy.dart`

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _CachedStream {
  final Uri url;
  final int totalBytes;
  final String mimeType;
  final DateTime createdAt;

  _CachedStream({
    required this.url,
    required this.totalBytes,
    required this.mimeType,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().difference(createdAt).inMinutes > 30;
}

class LocalAudioProxy {
  static final LocalAudioProxy _instance = LocalAudioProxy._internal();
  factory LocalAudioProxy() => _instance;
  LocalAudioProxy._internal();

  HttpServer? _server;
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _CachedStream> _cache = {};

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  /// Memulai server proxy HTTP lokal pada loopback IPv4 (127.0.0.1) dengan port dinamis
  Future<void> start() async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      debugPrint('[LocalAudioProxy] Started local proxy on http://127.0.0.1:${_server!.port}');

      _server!.listen(
        _handleRequest,
        onError: (e) {
          debugPrint('[LocalAudioProxy] Server error: $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[LocalAudioProxy] Failed to bind local server: $e');
    }
  }

  /// Menghasilkan URL proxy lokal dengan ekstensi `.m4a` untuk videoId tertentu
  Uri getProxyUrl(String videoId) {
    final serverPort = port;
    if (serverPort == 0) {
      debugPrint('[LocalAudioProxy] Warning: Local proxy not started yet! Port is 0');
    }
    // URL diakhiri dengan .m4a agar ExoPlayer Android mengenali MP4 container secara instan
    return Uri.parse('http://127.0.0.1:$serverPort/stream/$videoId.m4a');
  }

  /// Menangani request dari ExoPlayer dengan streaming chunked 512KB aman tanpa throttling
  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // Support CORS preflight
    if (request.method == 'OPTIONS') {
      response.headers.set('Access-Control-Allow-Origin', '*');
      response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      response.headers.set('Access-Control-Allow-Headers', '*');
      await response.close();
      return;
    }

    // Ekstraksi videoId dari path /stream/{id}.m4a atau query /stream?id={id}
    String? videoId;
    final path = request.uri.path;

    if (path.startsWith('/stream/')) {
      var rawId = path.substring('/stream/'.length);
      if (rawId.endsWith('.m4a')) {
        rawId = rawId.substring(0, rawId.length - '.m4a'.length);
      } else if (rawId.endsWith('.webm')) {
        rawId = rawId.substring(0, rawId.length - '.webm'.length);
      }
      videoId = rawId;
    } else if (path == '/stream') {
      videoId = request.uri.queryParameters['id'];
    }

    if (videoId == null || videoId.trim().isEmpty) {
      response.statusCode = HttpStatus.notFound;
      response.write('Invalid stream URL pattern');
      await response.close();
      return;
    }

    try {
      // 1. Ambil atau resolve stream info
      final streamInfo = await _getOrResolveStream(videoId.trim());
      final totalBytes = streamInfo.totalBytes;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      var start = 0;
      var end = totalBytes - 1;
      var isRange = false;

      // 2. Parse HTTP Range header (misal: "bytes=0-" atau "bytes=0-1024")
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        isRange = true;
        final rangeParts = rangeHeader.substring(6).split('-');
        if (rangeParts.isNotEmpty && rangeParts[0].isNotEmpty) {
          start = int.tryParse(rangeParts[0]) ?? 0;
        }
        if (rangeParts.length > 1 && rangeParts[1].isNotEmpty) {
          end = int.tryParse(rangeParts[1]) ?? (totalBytes - 1);
        } else {
          // Open-ended Range ("bytes=0-"): ExoPlayer mengharapkan rentang penuh hingga totalBytes - 1
          end = totalBytes - 1;
        }
      }

      if (start >= totalBytes) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$totalBytes');
        await response.close();
        return;
      }

      if (end >= totalBytes) {
        end = totalBytes - 1;
      }

      final contentLength = end - start + 1;

      // 3. Set response headers lengkap untuk ExoPlayer
      response.statusCode = isRange ? HttpStatus.partialContent : HttpStatus.ok;
      response.headers.set(HttpHeaders.contentTypeHeader, streamInfo.mimeType);
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(HttpHeaders.contentLengthHeader, contentLength.toString());
      response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
      response.headers.set('Access-Control-Allow-Origin', '*');
      response.headers.set('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');

      if (isRange) {
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalBytes');
      }

      // Jika request HEAD, selesai di sini
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }

      // 4. Unduh dan teruskan per-chunk 512KB ke ExoPlayer (mencegah throttling dan buffer deadlocks)
      const chunkSize = 512 * 1024; // 512 KB
      var curr = start;

      while (curr <= end) {
        final chunkEnd = (curr + chunkSize - 1) < end ? (curr + chunkSize - 1) : end;

        HttpClient? chunkClient;
        try {
          chunkClient = HttpClient();
          chunkClient.connectionTimeout = const Duration(seconds: 8);

          final chunkReq = await chunkClient.getUrl(streamInfo.url);
          chunkReq.headers.set(HttpHeaders.rangeHeader, 'bytes=$curr-$chunkEnd');
          chunkReq.headers.set(
            HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          );

          final chunkResp = await chunkReq.close();
          await for (final chunkData in chunkResp) {
            response.add(chunkData);
          }
          await response.flush();
          curr = chunkEnd + 1;
        } on SocketException catch (_) {
          // Socket ditutup oleh ExoPlayer (normal saat skip lagu atau selesai membaca header)
          break;
        } on HttpException catch (_) {
          break;
        } catch (e) {
          debugPrint('[LocalAudioProxy] Chunk transfer stopped for $videoId: $e');
          break;
        } finally {
          chunkClient?.close(force: true);
        }
      }

      try {
        await response.close();
      } catch (_) {}
    } catch (e) {
      debugPrint('[LocalAudioProxy] Error processing request for $videoId: $e');
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.write('Proxy error: $e');
        await response.close();
      } catch (_) {}
    }
  }

  /// Mendapatkan manifest stream audio terbaik menggunakan client androidVr & ios
  Future<_CachedStream> _getOrResolveStream(String videoId) async {
    final cached = _cache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached;
    }

    StreamManifest manifest;
    try {
      manifest = await _yt.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.androidVr,
              YoutubeApiClient.ios,
            ],
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 10));
    }

    final audioStreams = manifest.audioOnly;
    if (audioStreams.isEmpty) {
      throw Exception('No audio streams available for $videoId');
    }

    // Prioritaskan M4A/MP4 (itag 140) agar container audio terbaca instan oleh ExoPlayer
    final m4aStreams = audioStreams.where(
      (s) =>
          s.container.name.toLowerCase() == 'mp4' ||
          s.codec.mimeType.contains('mp4') ||
          s.tag == 140,
    ).toList();

    final selected = m4aStreams.isNotEmpty
        ? m4aStreams.last
        : audioStreams.withHighestBitrate();

    final cachedEntry = _CachedStream(
      url: selected.url,
      totalBytes: selected.size.totalBytes,
      mimeType: selected.codec.mimeType.isNotEmpty ? selected.codec.mimeType : 'audio/mp4',
      createdAt: DateTime.now(),
    );

    _cache[videoId] = cachedEntry;
    return cachedEntry;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _cache.clear();
  }

  void dispose() {
    stop();
    _yt.close();
  }
}
```

### 7.3. `lib/data/services/yt_service.dart`

```dart
import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track_model.dart';

class YtService {
  final YoutubeExplode _yt;

  YtService({YoutubeExplode? ytClient}) : _yt = ytClient ?? YoutubeExplode();

  static const List<String> curatedArtists = [
    'The Weeknd',
    'The Neighbourhood',
    'Billie Eilish',
    'Arctic Monkeys',
    'Frank Ocean',
    'Lana Del Rey',
    'Post Malone',
    'SZA',
    'Kendrick Lamar',
    'Joji',
    'Steve Lacy',
    'Daft Punk',
  ];

  static const List<String> blacklistedKeywords = [
    'remix',
    'dj',
    'koplo',
    'ngopi',
    'cover',
    'live',
    'bass boost',
    'jedag jedug',
    'tiktok',
    'full album',
    'slowed',
    'reverb',
    'reaction',
    'kompilasi',
    'mashup',
    'karaoke',
    'speed up',
    'sped up',
    'nightcore',
  ];

  final RegExp _emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );

  Future<List<TrackModel>> getCuratedWesternTrending({int limit = 25}) async {
    final tracks = <TrackModel>[];
    final seenIds = <String>{};

    final shuffledArtists = List<String>.from(curatedArtists)..shuffle();

    for (final artist in shuffledArtists.take(6)) {
      try {
        final query = '$artist - Topic';
        final searchResults = await _yt.search
            .search(query)
            .timeout(const Duration(seconds: 8));

        for (final video in searchResults) {
          final videoId = video.id.value;
          if (seenIds.contains(videoId)) continue;

          final title = video.title;
          final duration = video.duration ?? Duration.zero;
          final channel = video.author;

          // Duration filter: studio length (1m30s to 7m00s)
          if (duration.inSeconds < 90 || duration.inSeconds > 420) continue;

          // Reject emoji
          if (_emojiRegex.hasMatch(title)) continue;

          // Reject blacklisted keywords
          final lowerTitle = title.toLowerCase();
          if (blacklistedKeywords.any((kw) => lowerTitle.contains(kw))) continue;

          // Channel filter: prefer official artist channels or topic channels
          final isTopic = channel.endsWith(' - Topic');
          final isArtistChannel = channel.toLowerCase().contains(artist.toLowerCase());
          if (!isTopic && !isArtistChannel) continue;

          seenIds.add(videoId);
          final rawAuthor = channel.replaceAll(' - Topic', '').trim();
          final cleanAuthor = rawAuthor.isNotEmpty ? rawAuthor : artist;

          final artworkUrl = _formatThumbnailUrl(
            video.thumbnails.highResUrl,
            videoId,
          );

          tracks.add(
            TrackModel(
              id: videoId,
              title: _cleanTitle(title),
              artist: cleanAuthor,
              album: 'Official Release',
              duration: duration,
              artworkUrl: artworkUrl,
              youtubeVideoId: videoId,
            ),
          );

          if (tracks.length >= limit) return tracks;
        }
      } catch (_) {
        continue;
      }
    }

    return tracks;
  }

  Future<List<TrackModel>> searchTracks(
    String query, {
    int limit = 20,
  }) async {
    try {
      final sanitizedQuery = query.trim();
      if (sanitizedQuery.isEmpty) return [];

      final searchQuery = sanitizedQuery.toLowerCase().contains('audio') ||
              sanitizedQuery.toLowerCase().contains('topic')
          ? sanitizedQuery
          : '$sanitizedQuery Audio';

      final searchResults = await _yt.search
          .search(searchQuery)
          .timeout(const Duration(seconds: 10));

      final tracks = <TrackModel>[];

      for (final video in searchResults) {
        if (tracks.length >= limit) break;

        final videoId = video.id.value;
        final rawTitle = video.title;
        final duration = video.duration ?? Duration.zero;

        // Skip ultra-long albums or mixes (> 8 mins)
        if (duration.inSeconds > 480) continue;

        // Filter out spam/koplo/remix if not explicitly searched
        final lowerTitle = rawTitle.toLowerCase();
        if (!query.toLowerCase().contains('remix') &&
            blacklistedKeywords.any((kw) => lowerTitle.contains(kw))) {
          continue;
        }

        final rawAuthor = video.author.replaceAll(' - Topic', '').trim();
        String artist = rawAuthor.isNotEmpty ? rawAuthor : 'Unknown Artist';
        String title = rawTitle;

        // Extract "Artist - Title" format if present
        if (rawTitle.contains(' - ')) {
          final parts = rawTitle.split(' - ');
          if (parts.length >= 2) {
            final parsedArtist = parts[0].trim();
            final parsedTitle = parts.sublist(1).join(' - ').trim();
            if (parsedArtist.isNotEmpty && parsedTitle.isNotEmpty) {
              artist = parsedArtist;
              title = _cleanTitle(parsedTitle);
            }
          }
        } else {
          title = _cleanTitle(rawTitle);
        }

        final artworkUrl = _formatThumbnailUrl(
          video.thumbnails.highResUrl,
          videoId,
        );

        tracks.add(
          TrackModel(
            id: videoId,
            title: title,
            artist: artist,
            album: 'YouTube Music',
            duration: duration,
            artworkUrl: artworkUrl,
            youtubeVideoId: videoId,
          ),
        );
      }

      return tracks;
    } catch (e) {
      throw Exception('Failed to search tracks for "$query": $e');
    }
  }

  Future<Uri> resolveStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.androidVr,
              YoutubeApiClient.ios,
            ],
          )
          .timeout(const Duration(seconds: 10));

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        throw Exception('No audio streams available for $videoId');
      }

      // Prioritize M4A/AAC streams for rock-solid Android ExoPlayer compatibility
      final m4aStreams = audioStreams.where(
        (s) =>
            s.container.name.toLowerCase() == 'mp4' ||
            s.codec.mimeType.contains('mp4') ||
            s.tag == 140,
      ).toList();

      if (m4aStreams.isNotEmpty) {
        m4aStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
        return m4aStreams.last.url;
      }

      // Fallback to highest bitrate audio stream
      return audioStreams.withHighestBitrate().url;
    } catch (e) {
      throw Exception('Failed to resolve stream URL for video $videoId: $e');
    }
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*[\(\[]\s*official\s*audio\s*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[]\s*audio\s*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[]\s*lyrics?\s*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[]\s*official\s*video\s*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[]\s*official\s*music\s*video\s*[\)\]]', caseSensitive: false), '')
        .trim();
  }

  String _formatThumbnailUrl(String rawUrl, String videoId) {
    if (rawUrl.isEmpty) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    if (rawUrl.contains('=w') && rawUrl.contains('-h')) {
      return rawUrl.replaceAll(RegExp(r'=w\d+-h\d+'), '=w1000-h1000');
    }
    return rawUrl;
  }

  void dispose() {
    _yt.close();
  }
}
```
