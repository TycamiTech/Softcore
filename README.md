<div align="center">

# 🎧 Softcore

**A sleek, high-fidelity, ad-free Western music streaming application built with Flutter.**  
*Crafted for pure, original studio audio — zero remixes, zero mashups, and uninterrupted playback.*

[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-black?style=for-the-badge)](LICENSE)

</div>

---

## 🌟 Overview

**Softcore** is a modern music player tailored for Western music lovers who prioritize clean studio releases over bootlegs and unofficial remixes. Powered by a hybrid multi-tier streaming engine and a distraction-free dark UI, Softcore delivers instantaneous track playback with native lock-screen controls and offline caching.

---

## ✨ Features

- 🎵 **100% Original Studio Releases Only**
  - Robust anti-remix and anti-mashup filtering engine.
  - Automatically filters out bootlegs, DJ mixes, slowed+reverb, nightcore, bossa nova covers, and translated lyrics.
- ⚡ **Multi-Tier Audio Pipeline**
  - **Tier 1 (Instant Akamai CDN):** High-speed direct streaming from Akamai CDN servers with artist verification.
  - **Tier 2 (Download-to-Temp Cache):** Native YouTube stream extraction cached directly to local storage (`file://`), completely eliminating ExoPlayer `(0) Source Error` and network throttling.
  - **Tier 3 (Direct Stream Fallback):** Android Oculus Cronet streaming fallback for instant response.
- 📱 **Native Background Playback & MediaSession**
  - Seamless background audio using `just_audio` and `just_audio_background`.
  - Notification controls with live seekbar, play/pause, next/previous, and high-res album artwork.
- 🧭 **Curated Western Discovery**
  - Home feed curated for top artists (The Weeknd, Lana Del Rey, Billie Eilish, Frank Ocean, Arctic Monkeys, Post Malone, SZA, etc.).
  - Search engine pre-configured for Topic Channels and verified audio tracks.
- 📚 **Personal Library & Offline Cache**
  - Local SQLite database (`sqflite`) for Favorites and Recently Played tracks.
  - In-memory stream caching for instant repeat playback.
- 🎨 **Minimalist Immersive Player**
  - Fluid bottom mini-player and expanded full-screen player with vibrant gradient backgrounds derived from track artwork.

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── audio_player_service.dart   # JustAudio wrapper with MediaItem and notification lifecycle
│   └── local_audio_proxy.dart      # Local proxy utilities
├── data/
│   ├── models/                     # Immutable Track, Album, and Artist data structures
│   ├── repositories/
│   │   └── music_repository.dart   # Multi-tier audio resolution and track discovery
│   └── services/
│       ├── audiodb_service.dart    # Artist biography and album discography
│       ├── invidious_service.dart  # Alternative track search failover
│       ├── local_db_service.dart   # SQLite database for Favorites & History
│       ├── saavn_service.dart      # Direct CDN streaming engine with anti-remix heuristics
│       └── yt_service.dart         # YouTube Explode native audio extractor & temp cacher
└── presentation/
    ├── providers/
    │   └── player_provider.dart    # State management (Playback, Queue, Shuffle, Repeat)
    ├── screens/
    │   ├── artist_detail_screen.dart
    │   ├── home_screen.dart
    │   ├── library_screen.dart
    │   ├── main_screen.dart
    │   ├── player_screen.dart
    │   └── search_screen.dart
    └── widgets/
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.13.0` or higher)
- [Android SDK](https://developer.android.com/studio) (API 34+)
- JDK 17 (e.g. Azul Zulu 17)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/TycamiTech/Softcore.git
   cd Softcore
   ```

2. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```

3. **Run in debug mode on connected device:**
   ```bash
   flutter run
   ```

---

## 📦 Building the App

### Debug APK
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Production Release APK (Optimized & Shrunk ~54 MB)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🛠️ Tech Stack & Packages

| Package | Purpose |
| :--- | :--- |
| [`just_audio`](https://pub.dev/packages/just_audio) | Core audio playback engine |
| [`just_audio_background`](https://pub.dev/packages/just_audio_background) | Android MediaSession & lock-screen notification |
| [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart) | Direct YouTube audio stream extractor |
| [`provider`](https://pub.dev/packages/provider) | App-wide reactive state management |
| [`sqflite`](https://pub.dev/packages/sqflite) | Local relational storage for user library |
| [`dio`](https://pub.dev/packages/dio) | High-performance HTTP client for REST APIs |
| [`cached_network_image`](https://pub.dev/packages/cached_network_image) | Smooth image caching for album art |

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

<div align="center">
Made by <b>Tycami Tech</b>
</div>
