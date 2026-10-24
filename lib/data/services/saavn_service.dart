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

  static const List<String> _forbiddenKeywords = [
    'remix',
    'dj',
    'mashup',
    'slowed',
    'reverb',
    'lofi',
    'lo-fi',
    'cover',
    'karaoke',
    'instrumental',
    'tribute',
    '8d',
    'nightcore',
    'sped up',
    'bootleg',
    'bossa nova',
    'version',
    'techno',
    'hardstyle',
    'ambient',
    'edit',
    'mix',
    'medley',
  ];

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

  /// Validasi kecocokan kandidat lagu dari Saavn agar tidak mengambil cover/remix/DJ palsu
  bool _isValidMatch(
    String candidateTitle,
    String candidateArtists,
    String targetTitle,
    String targetArtist,
  ) {
    final lowerCandTitle = candidateTitle.toLowerCase();
    final lowerCandArtists = candidateArtists.toLowerCase();
    final lowerTargetTitle = targetTitle.toLowerCase();
    final lowerTargetArtist = targetArtist.toLowerCase().trim();

    // 1. Cek kata terlarang: tolak jika targetTitle TIDAK memuat kata terlarang tetapi kandidat memuatnya
    for (final kw in _forbiddenKeywords) {
      if (!lowerTargetTitle.contains(kw) && lowerCandTitle.contains(kw)) {
        return false;
      }
    }

    // 2. Bersihkan targetArtist dan verifikasi kecocokan nama artis
    if (lowerTargetArtist.isNotEmpty) {
      final cleanTargetArtist = lowerTargetArtist
          .replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\bvevo\b', caseSensitive: false), '')
          .trim();

      // Ekstrak nama artis utama pertama
      final artistParts = cleanTargetArtist.split(RegExp(r'[,&]|\b(feat\.?|ft\.?)\b', caseSensitive: false));
      final primaryArtist = (artistParts.isNotEmpty ? artistParts.first.trim() : cleanTargetArtist).toLowerCase();

      // Cek kecocokan nama artis lengkap atau artis utama
      bool matches = lowerCandArtists.contains(primaryArtist) ||
          lowerCandTitle.contains(primaryArtist) ||
          primaryArtist.contains(lowerCandArtists);

      if (!matches) {
        final tokens = primaryArtist
            .split(RegExp(r'[\s,&]+'))
            .where((t) => t.isNotEmpty && t != 'the' && t != 'a' && t != 'and')
            .toList();

        if (tokens.isNotEmpty) {
          final primaryKeyword = tokens.first;
          if (lowerCandArtists.contains(primaryKeyword) || lowerCandTitle.contains(primaryKeyword)) {
            matches = true;
          }
        }
      }

      if (!matches) {
        return false;
      }
    }

    return true;
  }

  /// Membersihkan judul lagu dari teks pengotor YouTube untuk meningkatkan akurasi pencarian
  String _cleanQuery(String title, String artist) {
    var cleanedTitle = title
        .replaceAll(RegExp(r'\((official|video|audio|lyrics?|feat\.?|ft\.?).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(official|video|audio|lyrics?|feat\.?|ft\.?).*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(official audio|official video|lyric video|music video)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(ft\.?|feat\.?)\b.*$', caseSensitive: false), '')
        .trim();

    var cleanedArtist = artist
        .replaceAll(RegExp(r' - Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bVEVO\b', caseSensitive: false), '')
        .trim();

    // Ambil nama artis utama pertama (hilangkan kolaborator agar pencarian Saavn akurat)
    final artistParts = cleanedArtist.split(RegExp(r'[,&]|\b(feat\.?|ft\.?)\b', caseSensitive: false));
    final primaryArtist = artistParts.isNotEmpty ? artistParts.first.trim() : cleanedArtist;

    if (primaryArtist.isNotEmpty && !cleanedTitle.toLowerCase().contains(primaryArtist.toLowerCase())) {
      return '$cleanedTitle $primaryArtist'.trim();
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
      final mirrorUrl = await _resolveFromMirrors(query, title, artist);
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
      final directUrl = await _resolveDirectSaavn(query, title, artist);
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
        final directUrl = await _resolveDirectSaavn(title.trim(), title, artist);
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

  /// Resolusi via mirror publik tidak resmi dengan validasi kecocokan ketat
  Future<String?> _resolveFromMirrors(String query, String targetTitle, String targetArtist) async {
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
            for (final song in songs) {
              if (song is! Map) continue;
              final candTitle = (song['name'] ?? song['title'] ?? song['song'] ?? '').toString();
              final candArtists = (song['primaryArtists'] ?? song['artists'] ?? song['singers'] ?? song['artist'] ?? '').toString();

              if (!_isValidMatch(candTitle, candArtists, targetTitle, targetArtist)) {
                continue;
              }

              final downloadUrl = song['downloadUrl'];
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
        }
      } catch (_) {
        // Coba mirror berikutnya
      }
    }
    return null;
  }

  /// Resolusi menggunakan endpoint resmi internal JioSaavn (Direct) dengan validasi kecocokan ketat
  Future<String?> _resolveDirectSaavn(String query, String targetTitle, String targetArtist) async {
    final uri = Uri.https('www.jiosaavn.com', '/api.php', {
      '__call': 'search.getResults',
      '_format': 'json',
      '_marker': '0',
      'n': '10',
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
          final candTitle = (item['song'] ?? item['title'] ?? '').toString();
          final candArtists = '${item['primary_artists'] ?? ''} ${item['singers'] ?? ''} ${item['music'] ?? ''}';

          if (!_isValidMatch(candTitle, candArtists, targetTitle, targetArtist)) {
            continue;
          }

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
