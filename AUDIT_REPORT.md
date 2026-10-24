# Laporan Audit Seni Bina Kod Sumber: Projek "Softcore"

**Peranan:** Senior Flutter & Mobile Audio Architect  
**Tarikh Audit:** 24 Oktober 2026  
**Dokumen:** Analisis Menyeluruh Seni Bina Aplikasi Mudah Alih  

---

## 1. Struktur Projek & Dependency

### 1.1 Analisis `pubspec.yaml`
Berdasarkan semakan ke atas fail `pubspec.yaml`, aplikasi ini dibangunkan pada Flutter SDK `^3.13.5` dengan pakej-pakej teras seperti berikut:

| Kategori | Pakej & Versi | Peranan Seni Bina | Status & Catatan |
| :--- | :--- | :--- | :--- |
| **Audio Engine** | `just_audio: ^0.9.40` | Enjin pemain audio berprestasi tinggi berteraskan ExoPlayer (Android) dan AVPlayer (iOS). | Teras (*core*) |
| **Background Audio** | `just_audio_background: ^0.0.1-beta.13` | Pengendalian Android MediaSession, Foreground Service, dan kawalan Media Center/Lockscreen. | Integrasi sistem |
| **Pengekstrakan Audio** | `youtube_explode_dart: ^3.1.0` | Pustaka *scraping* / pengurai dalaman YouTube untuk mencari lagu dan mengekstrak pautan strim audio mentah. | Berisiko tinggi usang (*fragile*) |
| **Rangkaian / HTTP** | `dio: ^5.7.0` | Klien HTTP dengan sokongan interceptor, pembatalan permintaan, dan pengurusan masa tamat (*timeouts*). | Digunakan dalam `AudioDbService` |
| **Penyimpanan Cache Imej**| `cached_network_image: ^3.4.0` | Memuat turun dan menyimpan cache visual/kulit album secara automatik. | Mengimport `sqflite` (transitif) |
| **State Management** | `provider: ^6.1.2` | Pengurusan keadaan reaktif berasaskan `ChangeNotifier`. | Mengawal `PlayerProvider` |
| **UI & Icons** | `cupertino_icons: ^1.0.8` | Ikon gaya iOS & Material Icons. | Lapisan pembentangan (*UI*) |

---

### 1.2 Struktur Direktori `lib/` & Corak Seni Bina
Struktur fail dalam `lib/` disusun mengikut corak **Layered Architecture** (terbahagi kepada `core`, `data`, dan `presentation`):

```text
lib/
├── main.dart                                # Titik masuk aplikasi, inisialisasi JustAudioBackground & Provider
├── core/                                    # Utiliti asas rentas aplikasi
│   ├── audio_player_service.dart            # Singleton pembungkus AudioPlayer
│   └── theme.dart                           # Definisi tema gelap, skema warna, dan tipografi
├── data/                                    # Lapisan pengurusan data mentah & luaran
│   ├── models/                              # Data Transfer Objects (DTO)
│   │   ├── album_model.dart                 # Model album artis
│   │   ├── artist_model.dart                # Model profil artis (TheAudioDB)
│   │   └── track_model.dart                 # Model lagu (identiti, metadata, pautan video)
│   ├── repositories/                        # Abstraksi data
│   │   └── music_repository.dart            # Menggabungkan servis YouTube & TheAudioDB
│   └── services/                            # Komunikasi API & scraping luaran
│       ├── audiodb_service.dart             # Klien TheAudioDB REST API (menggunakan Dio)
│       └── yt_service.dart                  # Pengekstrakan data & resolusi strim YouTube
└── presentation/                            # Antara muka pengguna (UI) & interaksi
    ├── providers/                           # State management berpusat
    │   └── player_provider.dart             # Status pemain, barisan giliran (queue), audio loop/shuffle
    ├── screens/                             # Paparan skrin penuh
    │   ├── artist_detail_screen.dart        # Diskografi, bio, dan senarai trek artis
    │   ├── home_screen.dart                 # Lagu trending dan artis pilihan
    │   ├── library_screen.dart              # Skrin koleksi pengguna (masih templat kosong)
    │   ├── main_screen.dart                 # Rangka navigasi bawah (IndexedStack & MiniPlayer)
    │   ├── player_screen.dart               # Skrin pemain audio penuh (seek bar, artwork, controls)
    │   └── search_screen.dart               # Carian lagu masa nyata dengan debounce timer
    └── widgets/                             # Komponen UI boleh guna semula
        ├── mini_player.dart                 # Pemain terapung di atas navigation bar
        └── track_tile.dart                  # Jubin senarai trek lagu
```

#### Penilaian Seni Bina:
1. **Pemisahan Lapisan (*Separation of Concerns*):** Wujud pengasingan yang baik antara panggilan API luaran (`data/services`), penyelarasan repositori (`data/repositories`), dan UI (`presentation/screens`).
2. **Kekurangan Domain Layer:** Projek tidak mempunyai lapisan domain tulen (*Use Cases / Interactors* atau pengasingan entiti perniagaan daripada DTO). Logik perniagaan seperti tapisan kata kunci lagu (`blacklistedKeywords`) diletakkan di dalam `YtService` dan bukannya dalam Use Case / Domain Policy.
3. **Penyelarasan State yang Tak Sekata:** Walaupun pemain audio dikendalikan secara berpusat melalui `PlayerProvider`, skrin seperti `HomeScreen`, `SearchScreen`, dan `ArtistDetailScreen` memulakan instance `MusicRepository` mereka sendiri secara berasingan menggunakan `StatefulWidget` tempatan tanpa sokongan Dependency Injection (DI) seperti `get_it`.

---

## 2. Logik Audio & Background Service

### 2.1 Konfigurasi Platform & Background Service
Integrasi audio latar belakang (*background audio playback*) dikonfigurasikan dengan standard Android MediaSession melalui `just_audio_background`:

1. **Inisialisasi Dart (`lib/main.dart`):**
```dart
await JustAudioBackground.init(
  androidNotificationChannelId: 'com.softcore.audio.channel',
  androidNotificationChannelName: 'Softcore Playback',
  androidNotificationOngoing: true,
);
```

2. **Kebenaran & Pengisytiharan Android (`android/app/src/main/AndroidManifest.xml`):**
   - Mengisytiharkan kebenaran: `INTERNET`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, dan `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
   - Mendaftarkan perkhidmatan latar belakang:
     - `com.ryanheise.just_audio.AudioService` dengan jenis `android:foregroundServiceType="mediaPlayback"`.
     - `com.ryanheise.just_audio.MediaButtonReceiver` untuk mengendalikan input butang fon kepala/alat kawalan luaran.

---

### 2.2 Singleton `AudioPlayerService`
Audio engine dibungkus sebagai kelas singleton di `lib/core/audio_player_service.dart`:
```dart
class AudioPlayerService {
  AudioPlayerService._internal();
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  Future<void> playUri(MediaItem item, Uri streamUri) async {
    final audioSource = AudioSource.uri(
      streamUri,
      tag: item,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      },
    );
    await _player.setAudioSource(audioSource);
    await _player.play();
  }
  ...
}
```

---

### 2.3 Pengendalian Kitaran Hayat Pemain Audio
Penyelarasan kitaran hayat audio berpusat dalam `PlayerProvider` (`lib/presentation/providers/player_provider.dart`):

```
┌─────────────────┐       playTrack()        ┌─────────────────────────┐
│ TrackTile / UI  ├─────────────────────────►│     PlayerProvider      │
└─────────────────┘                          └────────────┬────────────┘
                                                          │ 1. getAudioUrl(videoId)
                                                          ▼
                                             ┌─────────────────────────┐
                                             │     MusicRepository     │
                                             └────────────┬────────────┘
                                                          │ 2. resolveStreamUrl()
                                                          ▼
                                             ┌─────────────────────────┐
                                             │        YtService        │
                                             └────────────┬────────────┘
                                                          │ 3. Pautan Audio HTTPS
                                                          ▼
┌─────────────────┐   playUri(mediaItem, uri)┌─────────────────────────┐
│ just_audio native│◄────────────────────────┤   AudioPlayerService    │
│  (ExoPlayer/AV) │                          └─────────────────────────┘
└────────┬────────┘
         │ Event Stream (position, duration, playerState)
         ▼
┌─────────────────┐    notifyListeners()     ┌─────────────────────────┐
│  PlayerProvider ├─────────────────────────►│ MiniPlayer/PlayerScreen │
└─────────────────┘                          └─────────────────────────┘
```

#### Komponen Utama Aliran Audio:
1. **Playback State:** Didengar melalui `_audioService.playerStateStream`. Status dimuat turun (`ProcessingState.ready`), selesai (`ProcessingState.completed`), dan status main/jeda dipetakan terus ke pembolehubah `_isPlaying` dan `_isLoading`.
2. **Queue Management (Barisan Lagu):**
   - Projek ini **TIDAK menggunakan `ConcatenatingAudioSource`** daripada pustaka `just_audio`.
   - Pengurusan giliran dilakukan **secara manual dalam memori** (`List<TrackModel> _queue` dan penunjuk `_currentIndex`).
   - Apabila lagu tamat (`ProcessingState.completed`):
     ```dart
     if (state.processingState == ProcessingState.completed) {
       if (_isRepeat) {
         seek(Duration.zero);
         _audioService.resume();
       } else {
         next(); // Memulakan pengambilan URL baru untuk trek seterusnya secara bersiri
       }
     }
     ```
3. **Notification Player:** Dihasilkan secara langsung oleh `just_audio_background` berasaskan `MediaItem` yang disertakan pada `AudioSource.uri(streamUri, tag: item)`.
4. **Strategi Penstriman & Caching:**
   - Fail audio disalurkan melalui `AudioSource.uri(streamUri, tag: item, headers: {...})`.
   - **Tiada caching tempatan untuk fail audio** (cth. `LockCachingAudioSource` tidak diaplikasikan). Ini bermakna audio distrim secara terus (*progressive network stream*) dan perlu dimuat turun semula setiap kali trek diulang atau dimainkan kembali.

---

## 3. Integrasi API & Pengambilan Strim Muzik

### 3.1 Servis Rangkaian & Endpoint Semasa
Aplikasi bergantung kepada dua servis data luaran:

```
                          ┌───────────────────────────┐
                          │     MusicRepository       │
                          └──────┬─────────────┬──────┘
                                 │             │
                    ┌────────────┘             └────────────┐
                    ▼                                       ▼
       ┌────────────────────────┐              ┌────────────────────────┐
       │       YtService        │              │    AudioDbService      │
       │ (youtube_explode_dart) │              │      (Dio HTTP)        │
       └────────────┬───────────┘              └────────────┬───────────┘
                    │                                       │
                    ▼                                       ▼
       YouTube Web Engine / Scraping           TheAudioDB API v1 (JSON)
       • search.search(query)                  • /search.php?s={artist}
       • getManifest(videoId)                  • /discography.php?s={artist}
```

1. **`AudioDbService` (`lib/data/services/audiodb_service.dart`):**
   - Endpoint: `https://www.theaudiodb.com/api/v1/json/2`
   - Mengambil data profil artis (`/search.php?s=...`) dan senarai album (`/discography.php?s=...`).
2. **`YtService` (`lib/data/services/yt_service.dart`):**
   - Melaksanakan carian lagu YouTube dan penapisan teks (*topic channels*, larangan emoji, senarai hitam kata kunci `remix, dj, koplo, jedag jedug`).
   - Meleraikan strim audio melalui kaedah `_yt.videos.streamsClient.getManifest(videoId)`.

---

### 3.2 Punca Kegagalan Playback, Ralat Token/Cipher & HTTP 403 Forbidden
Dalam seni bina semasa, fungsi resolusi URL audio dalam `lib/data/services/yt_service.dart` berdepan kegagalan playback atas faktor teknikal berikut:

```dart
// Dari yt_service.dart
final manifest = await _yt.videos.streamsClient.getManifest(videoId);
final audioStreams = manifest.audioOnly;
// Memilih M4A / itag 140
return m4aStreams.last.url;
```

#### Analisis Kegagalan:
1. **Parameter `n` (Cipher Token Throttling):** YouTube menguatkuasakan transformasi dinamik kod JavaScript pemain (`base.js` / `player.js`) ke atas parameter `n`. Jika algoritma pengubah rentetan dalam `youtube_explode_dart` tidak dikemas kini selari dengan versi web YouTube terkini, YouTube akan mengehadkan kelajuan pemindahan (*throttling*) sehingga menyebabkan *audio buffering timeout*.
2. **Sekatan `PoToken` (Proof of Origin Token):** YouTube kini memerlukan token integriti bot (`visitor_data` dan `PoToken`) bagi mengesahkan permintaan bukan daripada automasi. Tanpa ini, pautan `googlevideo.com` yang diekstrak akan menerima status **HTTP 403 Forbidden** serta-merta apabila dimainkan oleh enjin audio peranti mudah alih.
3. **Jangka Hayat URL GoogleVideo Sangat Pendek:** Pautan CDN yang dijana terikat dengan alamat IP awam klien, parameter sesi, dan tamat tempoh (*expiry timestamp*). Jika terdapat kelewatan penstriman atau penukaran sambungan rangkaian (Wi-Fi ke Selular), sambungan terputus tanpa keupayaan memperbaharui pautan secara dinamik.
4. **Header Permintaan Tidak Sah:** `AudioPlayerService` menghantar header `User-Agent` statik pelayar desktop (`Mozilla/5.0 (Windows NT 10.0; ...)`), tetapi tidak menghantar parameter pelawat atau kuki yang sepadan, mencetuskan penolakan akses oleh gerbang keselamatan Google.

---

### 3.3 Skema Model Data Semasa
Model data teras perkhidmatan didefinisikan dalam `lib/data/models/track_model.dart`:

```dart
class TrackModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String artworkUrl;
  final String youtubeVideoId;
  ...
}
```

Format JSON yang dipetakan oleh model ini:
```json
{
  "id": "ggG9ySCChYw",
  "title": "Softcore",
  "artist": "The Neighbourhood",
  "album": "Hard To Imagine The Neighbourhood Ever Changing",
  "durationMs": 210000,
  "artworkUrl": "https://img.youtube.com/vi/ggG9ySCChYw/hqdefault.jpg",
  "youtubeVideoId": "ggG9ySCChYw"
}
```

---

## 4. Pengurusan Data Tempatan & Cache

### 4.1 Kedudukan `sqflite` dalam Projek
Melalui semakan fail `pubspec.yaml` dan pemetaan `pubspec.lock`, didapati:

1. **`sqflite` BUKAN Dependency Langsung:** Tiada entri `sqflite` diisytiharkan dalam `dependencies` pada `pubspec.yaml`.
2. **`sqflite` Hadir Sebagai Dependency Transitif:** `sqflite: 2.4.4+1` ditarik secara automatik oleh pakej rantai:
   $$\text{cached\_network\_image} \longrightarrow \text{flutter\_cache\_manager} \longrightarrow \text{sqflite}$$
3. **Peranan Sebenar `sqflite`:**
   - Digunakan **secara eksklusif oleh `flutter_cache_manager`** untuk menyimpan pangkalan data cache dalaman bagi metadata imej (kunci cache URL, laluan fail imej pada storan telefon, masa tamat tempoh/eviction).

---

### 4.2 Jurang Seni Bina Penyimpanan Data Tempatan
Pemeriksaan ke atas kod sumber mendedahkan kekurangan kritikal dari sudut penyimpanan data berterusan (*local persistence*):

| Ciri Data | Pengendalian Semasa | Implikasi Seni Bina |
| :--- | :--- | :--- |
| **Lagu Kegemaran (*Favorites*)** | `final Set<String> _favorites = {};` di `PlayerProvider` | **In-Memory Sahaja.** Semua lagu yang ditandakan sebagai kegemaran akan hilang apabila aplikasi ditutup. |
| **Sejarah Carian (*Search History*)** | Tidak disimpan. Carian memaparkan `_defaultResults` statik setiap kali skrin dibuka. | Pengalaman pengguna terjejas. |
| **Koleksi / Pustaka (*Library*)** | `LibraryScreen` memaparkan teks statik: *"Your collection is empty"*. | Tiada pangkalan data SQLite atau repositori luar talian untuk senarai main pengguna. |
| **Penyimpanan Cache Fail Audio** | Tiada integrasi `just_audio_cache` atau `LockCachingAudioSource`. | Penggunaan kuota data internet yang tinggi bagi lagu berulang. |

---

## 5. Pelan Migrasi & Penyesuaian ke Invidious API

Menggantikan `youtube_explode_dart` dengan **Invidious API** ialah langkah tepat bagi menghapuskan masalah *scraping breakages*, kegagalan cipher n-token, dan ralat HTTP 403.

```
SEBELUM:
  Flutter App ──► youtube_explode_dart (Scraping) ──► YouTube Frontend (Rentan 403/Cipher)

SELEPAS:
  Flutter App ──► Dio HTTP Client ──► Invidious Instance (/api/v1/) ──► Audio Stream URL
```

### 5.1 Fail dan Fungsi yang Perlu Diubah Suai

| Bil | Laluan Fail | Fungsi / Komponen Sedia Ada | Cadangan Pengubahsuaian |
| :---: | :--- | :--- | :--- |
| 1 | `pubspec.yaml` | `youtube_explode_dart: ^3.1.0` | Keluarkan pakej ini bagi meringankan saiz aplikasi dan menghapuskan kebergantungan *scraping*. |
| 2 | `lib/data/services/yt_service.dart` | Kelas `YtService` | Gantikan sepenuhnya dengan fail servis baharu (cth: `invidious_service.dart`) berasaskan `Dio`. |
| 3 | `lib/data/models/track_model.dart` | `TrackModel.fromJson` | Tambah `TrackModel.fromInvidious(Map<String, dynamic> json)` untuk memetakan respons JSON Invidious secara terus. |
| 4 | `lib/data/repositories/music_repository.dart` | `MusicRepository._ytService` | Gantikan instansiasi `YtService` kepada servis Invidious yang menguruskan *instance rotation* jika berlaku *rate-limit*. |

---

### 5.2 Spesifikasi Endpoint Invidious API

#### A. Carian Lagu (`/api/v1/search`)
- **Permintaan:** `GET https://{invidious_instance}/api/v1/search?q={query}&type=video`
- **Struktur Respons JSON:**
```json
[
  {
    "type": "video",
    "title": "Softcore",
    "videoId": "ggG9ySCChYw",
    "author": "The Neighbourhood",
    "lengthSeconds": 210,
    "videoThumbnails": [
      {
        "quality": "medium",
        "url": "https://invidious.io/vi/ggG9ySCChYw/mqdefault.jpg",
        "width": 320,
        "height": 180
      }
    ]
  }
]
```

#### B. Pengekstrakan Strim Audio (`/api/v1/videos/:id`)
- **Permintaan:** `GET https://{invidious_instance}/api/v1/videos/{videoId}`
- **Navigasi Objek JSON:** Cari tatasusunan `adaptiveFormats` dengan penapis `type` yang mengandungi `audio/mp4` atau `audio/webm`:
```json
{
  "title": "Softcore",
  "videoId": "ggG9ySCChYw",
  "adaptiveFormats": [
    {
      "init": "0-717",
      "index": "718-1249",
      "bitrate": "131456",
      "mimeType": "audio/mp4; codecs=\"mp4a.40.2\"",
      "container": "m4a",
      "type": "audio/mp4",
      "encoding": "aac",
      "audioQuality": "AUDIO_QUALITY_MEDIUM",
      "audioSampleRate": 44100,
      "audioChannels": 2,
      "url": "https://googlevideo.com/videoplayback?..."
    }
  ]
}
```

---

### 5.3 Coretan Kod Pelaksanaan: `InvidiousService`
Berikut ialah reka bentuk perkhidmatan pengganti yang disyorkan bagi menggantikan `yt_service.dart`, lengkap dengan keupayaan *instance fallback*:

```dart
import 'package:dio/dio.dart';
import '../models/track_model.dart';

class InvidiousService {
  final Dio _dio;

  // Senarai instance Invidious awam (dengan mekanisme fallback)
  final List<String> _instances = [
    'https://inv.tux.pizza',
    'https://invidious.nerdvpn.de',
    'https://vid.puffyan.us',
  ];
  int _currentInstanceIndex = 0;

  InvidiousService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  String get _baseUrl => _instances[_currentInstanceIndex];

  void _rotateInstance() {
    _currentInstanceIndex = (_currentInstanceIndex + 1) % _instances.length;
  }

  /// 1. Carian Trek Menggunakan /api/v1/search
  Future<List<TrackModel>> searchTracks(String query, {int limit = 20}) async {
    for (var attempt = 0; attempt < _instances.length; attempt++) {
      try {
        final response = await _dio.get(
          '$_baseUrl/api/v1/search',
          queryParameters: {
            'q': '$query audio',
            'type': 'video',
          },
        );

        if (response.statusCode == 200 && response.data is List) {
          final List results = response.data;
          return results
              .where((item) => item['type'] == 'video')
              .take(limit)
              .map<TrackModel>((item) {
                final videoId = item['videoId'] as String;
                final thumbnails = item['videoThumbnails'] as List?;
                final thumbUrl = thumbnails != null && thumbnails.isNotEmpty
                    ? thumbnails.first['url'] as String
                    : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

                return TrackModel(
                  id: videoId,
                  title: item['title'] as String? ?? 'Unknown Title',
                  artist: item['author'] as String? ?? 'Unknown Artist',
                  album: 'Invidious Music',
                  duration: Duration(seconds: item['lengthSeconds'] as int? ?? 0),
                  artworkUrl: thumbUrl,
                  youtubeVideoId: videoId,
                );
              })
              .toList();
        }
      } catch (e) {
        _rotateInstance(); // Bertukar ke instance lain jika berlaku kegagalan rangkaian
      }
    }
    return [];
  }

  /// 2. Resolusi Pautan Strim Menggunakan /api/v1/videos/:id -> adaptiveFormats
  Future<Uri> resolveStreamUrl(String videoId) async {
    for (var attempt = 0; attempt < _instances.length; attempt++) {
      try {
        final response = await _dio.get('$_baseUrl/api/v1/videos/$videoId');

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final adaptiveFormats = response.data['adaptiveFormats'] as List?;
          if (adaptiveFormats == null || adaptiveFormats.isEmpty) {
            throw Exception('No adaptive streams found');
          }

          // 1. Utamakan format audio M4A/AAC (keserasian optimum ExoPlayer & iOS)
          final audioStreams = adaptiveFormats.where((format) {
            final type = format['type'] as String? ?? '';
            return type.startsWith('audio/');
          }).toList();

          if (audioStreams.isEmpty) {
            throw Exception('No audio-only format available');
          }

          // 2. Susun mengikut bitrate tertinggi
          audioStreams.sort((a, b) {
            final brA = int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
            final brB = int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
            return brA.compareTo(brB);
          });

          final streamUrl = audioStreams.last['url'] as String?;
          if (streamUrl != null && streamUrl.isNotEmpty) {
            return Uri.parse(streamUrl);
          }
        }
      } catch (e) {
        _rotateInstance();
      }
    }
    throw Exception('Failed to resolve audio stream URL across all Invidious instances.');
  }
}
```

---

## 6. Pelan Tindakan Seni Bina Mengikut Keutamaan

```
PRIORITI 1: KRITIKAL (Kestabilan Main Semula)
├── 1. Gantikan youtube_explode_dart dengan InvidiousService (Menghapuskan 403 Forbidden & Cipher error).
└── 2. Tukar pengurusan AudioSource kepada LockCachingAudioSource (Menjimatkan data & menyokong buffer tempatan).

PRIORITI 2: SEDERHANA (Integriti Data & UX)
├── 3. Manfaatkan sqflite untuk menghasilkan SQLite Database tempatan (Menyimpan Favorites & History).
├── 4. Hubungkan LibraryScreen dengan database tempatan untuk paparan luar talian.
└── 5. Gunakan ConcatenatingAudioSource dalam just_audio untuk peralihan lagu secara lancar (gapless playback).
```
