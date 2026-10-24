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
