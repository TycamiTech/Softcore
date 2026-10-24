import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/track_model.dart';

class InvidiousService {
  final Dio _dio;

  // Daftar public instance Invidious dengan dukungan REST API & media proxy
  final List<String> _instances = [
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://inv.tux.pizza',
    'https://yewtu.be',
    'https://yt.chocolatemoo53.com',
    'https://invidious.jing.rocks',
  ];

  int _currentInstanceIndex = 0;

  InvidiousService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                  'Accept': 'application/json',
                },
              ),
            );

  String get currentBaseUrl => _instances[_currentInstanceIndex];

  void _rotateInstance() {
    _currentInstanceIndex = (_currentInstanceIndex + 1) % _instances.length;
    debugPrint('[InvidiousService] Switched to instance: $currentBaseUrl');
  }

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

  /// Mencari lagu menggunakan Invidious REST API dengan failover otomatis
  Future<List<TrackModel>> searchTracks(
    String query, {
    int limit = 20,
  }) async {
    final sanitizedQuery = query.trim();
    if (sanitizedQuery.isEmpty) return [];

    final initialIndex = _currentInstanceIndex;

    for (var attempt = 0; attempt < _instances.length; attempt++) {
      final baseUrl = currentBaseUrl;
      try {
        final response = await _dio.get(
          '$baseUrl/api/v1/search',
          queryParameters: {
            'q': '$sanitizedQuery official audio',
            'type': 'video',
          },
        );

        // Pastikan respon adalah list JSON murni (bukan halaman HTML antibot/challenge)
        if (response.statusCode == 200 && response.data is List) {
          final List rawList = response.data;
          final tracks = <TrackModel>[];

          for (final item in rawList) {
            if (tracks.length >= limit) break;
            if (item is! Map<String, dynamic>) continue;
            if (item['type'] != 'video') continue;

            final videoId = item['videoId'] as String? ?? '';
            final rawTitle = item['title'] as String? ?? '';
            final lengthSeconds = item['lengthSeconds'] as int? ?? 0;
            final author = item['author'] as String? ?? 'Unknown Artist';

            // Filter studio length (60s - 600s)
            if (lengthSeconds < 60 || lengthSeconds > 600) continue;

            // Reject emoji di judul
            if (_emojiRegex.hasMatch(rawTitle)) continue;

            // Reject kata kunci terlarang
            final lowerTitle = rawTitle.toLowerCase();
            if (!query.toLowerCase().contains('remix') &&
                blacklistedKeywords.any((kw) => lowerTitle.contains(kw))) {
              continue;
            }

            // Bersihkan judul dan artis
            String artist = author.replaceAll(' - Topic', '').trim();
            String title = _cleanTitle(rawTitle);

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
            }

            // Gunakan thumbnail resmi YouTube CDN agar selalu berhasil di-load di HP
            final artworkUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

            tracks.add(
              TrackModel(
                id: videoId,
                title: title,
                artist: artist,
                album: 'Official Audio',
                duration: Duration(seconds: lengthSeconds),
                artworkUrl: artworkUrl,
                youtubeVideoId: videoId,
              ),
            );
          }

          if (tracks.isNotEmpty) {
            return tracks;
          }
        } else {
          // Response bukan list JSON valid, putar ke instance berikutnya
          _rotateInstance();
        }
      } catch (e) {
        debugPrint('[InvidiousService] search error on $baseUrl: $e');
        _rotateInstance();
      }
    }

    _currentInstanceIndex = initialIndex;
    throw Exception('InvidiousService: All instances failed to search for "$query"');
  }

  /// Mengekstrak stream audio & memproksikannya melalui Invidious (Anti HTTP 403 Forbidden)
  Future<Uri> resolveStreamUrl(String videoId) async {
    final initialIndex = _currentInstanceIndex;

    for (var attempt = 0; attempt < _instances.length; attempt++) {
      final baseUrl = currentBaseUrl;
      final baseUri = Uri.parse(baseUrl);

      try {
        final response = await _dio.get(
          '$baseUrl/api/v1/videos/$videoId',
          queryParameters: {
            'local': 'true',
          },
        );

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          final adaptiveFormats = data['adaptiveFormats'];

          if (adaptiveFormats is List && adaptiveFormats.isNotEmpty) {
            final audioFormats = <Map<String, dynamic>>[];

            for (final format in adaptiveFormats) {
              if (format is Map<String, dynamic>) {
                final type = (format['type'] as String? ?? '').toLowerCase();
                final mimeType = (format['mimeType'] as String? ?? '').toLowerCase();
                if (type.startsWith('audio/') || mimeType.startsWith('audio/')) {
                  audioFormats.add(format);
                }
              }
            }

            if (audioFormats.isNotEmpty) {
              // 1. Prioritaskan audio/mp4 (m4a/aac) untuk kompatibilitas ExoPlayer & iOS
              final m4aFormats = audioFormats.where((f) {
                final type = (f['type'] as String? ?? '').toLowerCase();
                final mimeType = (f['mimeType'] as String? ?? '').toLowerCase();
                final container = (f['container'] as String? ?? '').toLowerCase();
                return type.contains('mp4') || mimeType.contains('mp4') || container == 'm4a';
              }).toList();

              final candidateList = m4aFormats.isNotEmpty ? m4aFormats : audioFormats;

              // 2. Urutkan berdasarkan bitrate tertinggi
              candidateList.sort((a, b) {
                final brA = int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
                final brB = int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
                return brA.compareTo(brB);
              });

              final selectedFormat = candidateList.last;
              final rawUrl = selectedFormat['url'] as String? ?? '';

              if (rawUrl.isNotEmpty) {
                return _buildProxiedUri(rawUrl, baseUri);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[InvidiousService] resolveStreamUrl error on $baseUrl for video $videoId: $e');
        _rotateInstance();
      }
    }

    _currentInstanceIndex = initialIndex;
    throw Exception('InvidiousService: Failed to resolve stream URL for $videoId across all instances');
  }

  /// Membangun Uri proxy aman agar tidak terblokir HTTP 403 Forbidden
  Uri _buildProxiedUri(String rawUrl, Uri baseUri) {
    final parsed = Uri.parse(rawUrl);

    // Kasus 1: URL berupa relative path (diawali /videoplayback)
    if (!parsed.isAbsolute || rawUrl.startsWith('/')) {
      final cleanPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
      return Uri.parse('${baseUri.origin}$cleanPath');
    }

    // Kasus 2: Host adalah googlevideo.com (rentan 403 jika diakses langsung tanpa proxy)
    if (parsed.host.contains('googlevideo.com')) {
      final originalHost = parsed.host;
      final mergedParams = Map<String, String>.from(parsed.queryParameters);
      mergedParams['local'] = 'true';
      mergedParams['host'] = originalHost;

      return parsed.replace(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: baseUri.hasPort ? baseUri.port : null,
        queryParameters: mergedParams,
      );
    }

    // Kasus 3: URL sudah diproksi oleh Invidious secara lengkap
    return parsed;
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
}
