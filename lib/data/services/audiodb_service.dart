import 'package:dio/dio.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';

class AudioDbService {
  final Dio _dio;

  AudioDbService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://www.theaudiodb.com/api/v1/json/2',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  Future<ArtistModel?> getArtist(String artistName) async {
    final trimmedName = artistName.trim();
    if (trimmedName.isEmpty) return null;

    try {
      final response = await _dio.get(
        '/search.php',
        queryParameters: {'s': trimmedName},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['artists'] != null) {
          final artistsList = data['artists'];
          if (artistsList is List && artistsList.isNotEmpty) {
            final artistJson = artistsList.first;
            if (artistJson is Map<String, dynamic>) {
              final rawName = artistJson['strArtist'] as String?;
              return ArtistModel(
                name: (rawName != null && rawName.trim().isNotEmpty)
                    ? rawName.trim()
                    : trimmedName,
                fanartUrl: artistJson['strArtistFanart'] as String?,
                logoUrl: artistJson['strArtistLogo'] as String?,
                bio: artistJson['strBiographyEN'] as String?,
                bannerUrl: (artistJson['strArtistBanner'] ??
                    artistJson['strArtistWideThumb']) as String?,
              );
            }
          }
        }
      }
      return null;
    } on DioException {
      // Graceful null-safe fallback when artist is not found or connection fails
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<AlbumModel>> getArtistAlbums(String artistName) async {
    final trimmedName = artistName.trim();
    if (trimmedName.isEmpty) return [];

    try {
      final response = await _dio.get(
        '/discography.php',
        queryParameters: {'s': trimmedName},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['album'] != null) {
          final albumsList = data['album'];
          if (albumsList is List) {
            return albumsList.map((item) {
              return AlbumModel(
                title: item['strAlbum'] as String? ?? 'Unknown Album',
                year: item['intYearReleased']?.toString(),
              );
            }).toList();
          }
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
