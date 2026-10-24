# Laporan Diagnostik Mendalam: Kegagalan Pemutaran Audio di Android Mobile (Projek "Softcore")

**Dokumen:** Analisis Teknis Masalah Playback & Panduan untuk AI / Audio Architect  
**Tanggal:** 24 Oktober 2026  
**Target Platform:** Android (ExoPlayer via `just_audio` & `audio_service`)  
**Status Masalah:** Gambar profil/artwork berhasil 100%, UI dan SQLite normal, namun **audio mengalami buffering tanpa henti (infinite loading) di perangkat Android fisik**.

---

## 1. Ringkasan Status Sistem Saat Ini

| Komponen | Status | Keterangan |
| :--- | :---: | :--- |
| **Pencarian Lagu (Search & Trending)** | ✅ Berhasil | Berjalan normal via Invidious & fallback `youtube_explode_dart`. |
| **Gambar Sampul Album / Artwork** | ✅ Berhasil | 100% muncul menggunakan CDN resmi Google (`https://i.ytimg.com/vi/$videoId/hqdefault.jpg`). |
| **Pangkalan Data Lokal (`sqflite`)** | ✅ Berhasil | SQLite mengelola *Favorites*, *Recently Played*, dan *Search History* secara persisten via `LocalDbService`. |
| **Deklarasi Background Service** | ✅ Berhasil | Diperbaiki di `AndroidManifest.xml` menjadi `com.ryanheise.audioservice.AudioService`. |
| **Pemutaran di Browser Chrome (PC)** | ✅ Berhasil | Audio berputar normal dengan kontrol pemutar responsif. |
| **Pemutaran di HP Android Fisik** | ❌ Gagal | **Spinner berputar tanpa henti (infinite loading/buffering), tidak ada suara yang keluar.** |

---

## 2. Aliran Data Pemutaran Audio Saat Ini

```
[UI TrackTile / PlayerScreen]
           │
           ▼
[PlayerProvider.playTrack(track)]
           │
           ▼
[MusicRepository.getAudioUrl(videoId)]
     ├── 1. Coba YtService.resolveStreamUrl(videoId) -> mengembalikan URL googlevideo.com
     └── 2. Bungkus dengan Cloudflare Worker Relay:
            https://softcore-relay.tycamewing7.workers.dev/relay?url=<encoded_googlevideo_url>
           │
           ▼
[AudioPlayerService.playUri(mediaItem, streamUri)]
     ├── await _player.stop();
     ├── AudioSource.uri(streamUri, tag: item, headers: { User-Agent: Mobile })
     ├── await _player.setAudioSource(audioSource);  <--- STUCK DI SINI DI ANDROID
     └── await _player.play();
```

---

## 3. Analisis Akar Masalah Teknis (Root Cause Analysis)

Mengapa di browser PC audio berputar, sedangkan di HP Android loading selamanya? Berikut adalah 4 kendala teknis tingkat rendah (*low-level constraints*) yang terjadi:

### Masalah 3.1: Validasi Ketat IP Binding pada URL GoogleVideo (`&ip=...`)
URL audio mentah yang diekstrak dari YouTube (`googlevideo.com/videoplayback?...`) memiliki parameter wajib:
$$\text{URL Query Parameter: } \texttt{\&ip=103.xxx.xxx.xxx}$$
* Parameter `&ip=` ini mengunci (*bind*) URL tersebut **hanya boleh diunduh oleh IP perangkat yang meminta manifest pertama kali**.
* **Ketika dialihkan ke Cloudflare Worker Relay:**
  * Cloudflare Worker mengambil audio dari server Edge Cloudflare (IP Datacenter AS / Eropa).
  * Server Google mendeteksi ketidakcocokan antara IP pengunduh (Cloudflare) dengan IP yang tercantum di parameter `&ip=` (IP HP/klien pengguna).
  * **Respon Google:** Google langsung memutuskan koneksi, mengembalikan `403 Forbidden`, atau menggantungkan soket HTTP (*socket hanging*).

### Masalah 3.2: Keterbatasan Eksekusi Streaming pada Cloudflare Worker Free Tier
* ExoPlayer di Android memutar audio menggunakan mekanisme **HTTP Range Requests** (`bytes=0-`, `bytes=1048576-`, dsb.) dengan status `206 Partial Content`.
* Cloudflare Worker gratis memiliki batasan ketat:
  * **Batas CPU Execution Time 50ms per permintaan.**
  * Pemutaran audio berkelanjutan (*continuous streaming body*) sering kali dihentikan sepihak oleh runtime Cloudflare karena koneksi dianggap melebihi batas eksekusi worker non-enterprise.
  * Akibatnya, ExoPlayer tidak menerima chunk audio secara berkesinambungan.

### Masalah 3.3: Silent Throttling Google (BotGuard / PoToken) pada Direct Connection
Jika URL `googlevideo.com` diputar langsung tanpa worker di HP Android:
* Google menerapkan sistem integritas **PoToken (Proof of Origin Token)**.
* Di Chrome PC, browser menjalankan engine JavaScript V8 resmi Google sehingga token pelawat tervalidasi secara otomatis.
* Di HP Android, pemutaran dilakukan oleh **ExoPlayer (C++/Java native engine)** yang tidak menjalankan JavaScript.
* Ketika Google mendeteksi koneksi ExoPlayer tanpa PoToken, Google tidak selalu membalas dengan status 403, melainkan menerapkan **Silent Throttling (menurunkan kecepatan transfer data menjadi 0 kbps)**.
* Dampaknya: ExoPlayer tidak pernah menerima header `Content-Type` atau byte pertama audio, sehingga status pemutar tetap terkunci pada `ProcessingState.buffering` (`_isLoading = true`) selamanya.

### Masalah 3.4: Runtuhnya Ekosistem Public Invidious Media Proxy
* Seluruh server publik Invidious (`inv.nadeko.net`, `inv.tux.pizza`, `yewtu.be`, dll.) telah mematikan fitur `/videoplayback` atau diblokir secara massal oleh Google karena beban kuota bandwidth video yang sangat masif.

---

## 4. Opsi Solusi Arsitektur untuk Rekomendasi AI / Engineer

Berdasarkan kendala teknis di atas, berikut adalah 3 opsi perbaikan arsitektur permanen yang dapat dipertimbangkan:

---

### 🟢 Solusi Rekomendasi 1: Local In-App HTTP Proxy (Shelf Localhost)
Menjalankan mini web server lokal (`shelf` / `HttpServer.bind('127.0.0.1', port)`) di dalam aplikasi Flutter:
1. ExoPlayer meminta audio ke: `http://127.0.0.1:<port>/stream?id=$videoId`.
2. Server lokal di dalam HP membaca stream audio chunk demi chunk menggunakan socket Dart native (yang berjalan di IP HP yang sama persis dengan `youtube_explode_dart`), menyuntikkan header byte-range yang benar, lalu meneruskannya ke ExoPlayer.
3. **Kelebihan:** 100% berjalan lokal di HP tanpa server luar, tidak ada masalah IP mismatch, dan sepenuhnya gratis.

---

### 🟢 Solusi Rekomendasi 2: Migrasi ke Audio API Pihak Ketiga (Bukan Scraping Google)
Menggantikan ekstraksi scraping YouTube yang rentan dengan API musik resmi yang menyediakan pautan file `.mp3` langsung (Direct High-Quality Audio Stream):
1. **Audius API (Gratis & Open Source):**
   * Endpoint: `https://discoveryprovider.audius.co/v1/tracks/search?query=...`
   * Stream: `https://discoveryprovider.audius.co/v1/tracks/{track_id}/stream`
   * Menyediakan jutaan lagu dengan format 320kbps MP3 langsung tanpa cipher, tanpa token bot, dan tanpa batasan IP.
2. **JioSaavn / Deezer Unofficial API:**
   * Menyediakan koleksi lagu barat mainstream (The Weeknd, Billie Eilish, dll.) dengan direct stream URL CDN Akamai/Cloudflare resmi yang kompatibel 100% dengan ExoPlayer.

---

### 🟢 Solusi Rekomendasi 3: Dedicated Self-Hosted Proxy dengan YouTube Cookie / PoToken Generator
Jika tetap ingin menggunakan YouTube:
1. Menghosting microservice pribadi (Node.js / Python FastAPI dengan `yt-dlp` atau `piped-backend`) pada VPS murah (misal Oracle Cloud Free Tier / VPS $3/bulan).
2. Server tersebut menjalankan generator PoToken otomatis dan mem-proxy audio stream secara penuh ke aplikasi Android.

---

## 5. Ringkasan File Kunci Terkait Masalah Ini

| File | Baris | Peran / Isu |
| :--- | :--- | :--- |
| [`lib/core/audio_player_service.dart`](file:///d:/Repositories/Softcore/lib/core/audio_player_service.dart#L20-L40) | 20–40 | Inisialisasi `AudioSource.uri` ke ExoPlayer. |
| [`lib/data/repositories/music_repository.dart`](file:///d:/Repositories/Softcore/lib/data/repositories/music_repository.dart#L85-L115) | 85–115 | Logika pembungkusan URL relay Cloudflare Worker. |
| [`lib/data/services/yt_service.dart`](file:///d:/Repositories/Softcore/lib/data/services/yt_service.dart#L198-L225) | 198–225 | Ekstraksi manifest audio YouTube Explode. |
| [`cloudflare_worker/worker.js`](file:///d:/Repositories/Softcore/cloudflare_worker/worker.js#L27-L67) | 27–67 | Endpoint `/relay` penanganan forwarding HTTP Range request. |
