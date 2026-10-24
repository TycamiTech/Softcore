class AlbumModel {
  final String title;
  final String? year;
  final String? artworkUrl;

  const AlbumModel({
    required this.title,
    this.year,
    this.artworkUrl,
  });
}
