class ArtistModel {
  final String name;
  final String? fanartUrl;
  final String? logoUrl;
  final String? bio;
  final String? bannerUrl;

  const ArtistModel({
    required this.name,
    this.fanartUrl,
    this.logoUrl,
    this.bio,
    this.bannerUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'fanartUrl': fanartUrl,
        'logoUrl': logoUrl,
        'bio': bio,
        'bannerUrl': bannerUrl,
      };

  factory ArtistModel.fromJson(Map<String, dynamic> json) => ArtistModel(
        name: json['name'] as String? ?? '',
        fanartUrl: json['fanartUrl'] as String?,
        logoUrl: json['logoUrl'] as String?,
        bio: json['bio'] as String?,
        bannerUrl: json['bannerUrl'] as String?,
      );
}
