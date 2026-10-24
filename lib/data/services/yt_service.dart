import 'dart:async';
import 'dart:io';
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
    'mashup',
    ' x ',
    'vs',
    'tradução',
    'traducao',
    'legendado',
    'sub español',
    'lirik',
    'terjemahan',
    'bossa nova',
    'acoustic',
    'cover',
    'live',
    'karaoke',
    'instrumental',
    'slowed',
    'reverb',
    'sped up',
    'speed up',
    'nightcore',
    '8d',
    'bass boost',
    'koplo',
    'jedag jedug',
    'full album',
    'playlist',
    'mix',
    'reaction',
    'kompilasi',
    'tiktok',
    'ngopi',
  ];

  final RegExp _emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );

  final Map<String, Uri> _resolvedUrlCache = {};

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

          // Reject blacklisted keywords and mashups
          final lowerTitle = title.toLowerCase();
          if (lowerTitle.contains(' x ') || lowerTitle.contains(' vs ')) continue;
          if (blacklistedKeywords.any((kw) => lowerTitle.contains(kw))) continue;

          // Channel filter: WAJIB hanya channel Topic, VEVO, atau nama artis resmi
          final isTopic = channel.endsWith(' - Topic');
          final isVevo = channel.toUpperCase().contains('VEVO');
          final isExactArtist = channel.trim().toLowerCase() == artist.trim().toLowerCase();
          if (!isTopic && !isVevo && !isExactArtist) continue;

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

      final searchQuery = '$sanitizedQuery - Topic official audio';

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

        // Tolak jika judul mengandung mashup ' x ' atau ' vs '
        final lowerTitle = rawTitle.toLowerCase();
        if (lowerTitle.contains(' x ') || lowerTitle.contains(' vs ')) continue;

        // Filter out spam/koplo/remix if not explicitly searched
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

  Future<Uri> resolveFastAudioUri(String videoId) async {
    if (_resolvedUrlCache.containsKey(videoId)) {
      return _resolvedUrlCache[videoId]!;
    }

    try {
      StreamManifest manifest;
      try {
        manifest = await _yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [
                YoutubeApiClient.androidSdkless,
                YoutubeApiClient.androidVr,
              ],
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        manifest = await _yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [
                YoutubeApiClient.androidVr,
                YoutubeApiClient.safari,
                YoutubeApiClient.ios,
              ],
            )
            .timeout(const Duration(seconds: 8));
      }

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        throw Exception('No audio streams available for $videoId');
      }

      // Utamakan stream container mp4 (itag 140 / m4a) atau webm (itag 250 / 251) dengan ukuran yang efisien
      final m4aStreams = audioStreams.where(
        (s) =>
            s.container.name.toLowerCase() == 'mp4' ||
            s.codec.mimeType.contains('mp4') ||
            s.tag == 140,
      ).toList();

      AudioStreamInfo selectedStream;
      if (m4aStreams.isNotEmpty) {
        m4aStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
        selectedStream = m4aStreams.last;
      } else {
        final webmStreams = audioStreams.where(
          (s) =>
              s.container.name.toLowerCase() == 'webm' ||
              s.tag == 251 ||
              s.tag == 250,
        ).toList();
        if (webmStreams.isNotEmpty) {
          webmStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
          selectedStream = webmStreams.last;
        } else {
          selectedStream = audioStreams.withHighestBitrate();
        }
      }

      final resolvedUri = selectedStream.url;
      _resolvedUrlCache[videoId] = resolvedUri;
      return resolvedUri;
    } catch (e) {
      throw Exception('Failed to resolve fast audio URI for video $videoId: $e');
    }
  }

  Future<Uri> resolveStreamUrl(String videoId) async {
    return resolveFastAudioUri(videoId);
  }

  /// Mengunduh stream audio YouTube resmi langsung ke file temporary lokal (file://)
  /// Menghindari isu ExoPlayer (0) Source Error dan loopback proxy 127.0.0.1
  Future<Uri> downloadToTempFile(String videoId) async {
    final tempDir = Directory.systemTemp.path;

    // Cek cache lokal jika sudah pernah diunduh dan valid (> 10KB)
    try {
      final cachedFiles = Directory(tempDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('softcore_$videoId.') && f.lengthSync() > 10000)
          .toList();

      if (cachedFiles.isNotEmpty) {
        return Uri.file(cachedFiles.first.path);
      }
    } catch (_) {}

    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.androidSdkless,
              YoutubeApiClient.ios,
              YoutubeApiClient.androidVr,
              YoutubeApiClient.safari,
            ],
            requireWatchPage: false,
          )
          .timeout(const Duration(seconds: 8));

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        throw Exception('No audio streams available for $videoId');
      }

      // Prioritaskan m4a / mp4 dengan bitrate yang efisien agar download selesai dalam 1-2 detik
      final m4aStreams = audioStreams.where(
        (s) =>
            s.container.name.toLowerCase() == 'mp4' ||
            s.codec.mimeType.contains('mp4') ||
            s.tag == 140,
      ).toList();

      AudioStreamInfo selectedStream;
      if (m4aStreams.isNotEmpty) {
        m4aStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
        selectedStream = m4aStreams.first;
        if (m4aStreams.length > 1 && m4aStreams.first.bitrate.bitsPerSecond < 64000) {
          selectedStream = m4aStreams.last;
        }
      } else {
        selectedStream = audioStreams.withHighestBitrate();
      }

      final ext = selectedStream.container.name;
      final file = File('$tempDir/softcore_$videoId.$ext');

      try {
        final stream = _yt.videos.streamsClient.get(selectedStream);
        final output = file.openWrite();
        await stream.pipe(output);
        await output.flush();
        await output.close();
      } catch (err) {
        final client = HttpClient();
        try {
          final req = await client.getUrl(selectedStream.url);
          req.headers.set(
            'User-Agent',
            'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
          );
          final res = await req.close();
          if (res.statusCode == 200 || res.statusCode == 206) {
            final output = file.openWrite();
            await res.pipe(output);
            await output.flush();
            await output.close();
          }
        } finally {
          client.close();
        }
      }

      if (file.lengthSync() <= 10000) {
        throw Exception('Downloaded audio file is invalid or too small: ${file.lengthSync()} bytes');
      }

      return Uri.file(file.path);
    } catch (e) {
      throw Exception('Failed to download audio to temp file for video $videoId: $e');
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
