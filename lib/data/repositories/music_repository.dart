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
