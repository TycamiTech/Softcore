import 'package:just_audio_background/just_audio_background.dart';

class TrackModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String artworkUrl;
  final String youtubeVideoId;

  const TrackModel({
    required this.id,
    required this.title,
    required this.artist,
    this.album = 'Unknown Album',
    this.duration = Duration.zero,
    required this.artworkUrl,
    required this.youtubeVideoId,
  });

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      album: album,
      title: title,
      artist: artist,
      duration: duration,
      artUri: artworkUrl.isNotEmpty ? Uri.tryParse(artworkUrl) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'artworkUrl': artworkUrl,
        'youtubeVideoId': youtubeVideoId,
      };

  factory TrackModel.fromJson(Map<String, dynamic> json) => TrackModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String? ?? 'Unknown Album',
        duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
        artworkUrl: json['artworkUrl'] as String? ?? '',
        youtubeVideoId: json['youtubeVideoId'] as String? ?? '',
      );
}
