import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/album_model.dart';
import '../../data/models/artist_model.dart';
import '../../data/models/track_model.dart';
import '../../data/repositories/music_repository.dart';
import '../providers/player_provider.dart';
import '../widgets/track_tile.dart';

class ArtistDetailScreen extends StatefulWidget {
  final ArtistModel artist;

  const ArtistDetailScreen({
    super.key,
    required this.artist,
  });

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final MusicRepository _repository = MusicRepository();

  ArtistModel? _detailedArtist;
  List<TrackModel> _artistTracks = [];
  List<AlbumModel> _albums = [];
  bool _isLoading = true;
  bool _isBioExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    setState(() {
      _isLoading = true;
    });

    final artistName = widget.artist.name;

    try {
      // Parallel fetch for details, tracks, and albums
      final results = await Future.wait([
        _repository.getArtistDetails(artistName),
        _repository.search('$artistName Top Songs Audio'),
        _repository.getArtistAlbums(artistName),
      ]);

      if (mounted) {
        setState(() {
          _detailedArtist = results[0] as ArtistModel? ?? widget.artist;
          _artistTracks = (results[1] as List<TrackModel>).isNotEmpty
              ? (results[1] as List<TrackModel>)
              : _generateFallbackTracks(artistName);
          _albums = results[2] as List<AlbumModel>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detailedArtist = widget.artist;
          _artistTracks = _generateFallbackTracks(artistName);
          _isLoading = false;
        });
      }
    }
  }

  List<TrackModel> _generateFallbackTracks(String artistName) {
    return [
      TrackModel(
        id: 'fallback_1_$artistName',
        title: 'Popular Track 1',
        artist: artistName,
        album: '$artistName Collection',
        duration: const Duration(minutes: 3, seconds: 40),
        artworkUrl: widget.artist.fanartUrl ?? '',
        youtubeVideoId: 'fallback_1',
      ),
      TrackModel(
        id: 'fallback_2_$artistName',
        title: 'Popular Track 2',
        artist: artistName,
        album: '$artistName Collection',
        duration: const Duration(minutes: 4, seconds: 12),
        artworkUrl: widget.artist.fanartUrl ?? '',
        youtubeVideoId: 'fallback_2',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final artist = _detailedArtist ?? widget.artist;
    final bannerUrl = artist.bannerUrl ?? artist.fanartUrl ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Banner Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.scaffoldBackground,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryText),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (bannerUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppColors.cardSurface),
                      errorWidget: (context, url, error) => Container(color: AppColors.cardSurface),
                    )
                  else
                    Container(
                      color: AppColors.cardSurface,
                      child: const Center(
                        child: Icon(Icons.person, size: 80, color: AppColors.secondaryText),
                      ),
                    ),
                  // Spotify-style gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.scaffoldBackground.withValues(alpha: 0.2),
                          AppColors.scaffoldBackground.withValues(alpha: 0.8),
                          AppColors.scaffoldBackground,
                        ],
                        stops: const [0.0, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                  // Artist Name on Header Bottom
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VERIFIED ARTIST',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artist.name,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions Bar: Play All & Shuffle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Popular Songs',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_artistTracks.isNotEmpty)
                    Consumer<PlayerProvider>(
                      builder: (context, player, child) {
                        return GestureDetector(
                          onTap: () {
                            player.playTrack(_artistTracks.first, newQueue: _artistTracks);
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryText,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.scaffoldBackground,
                                size: 32,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Popular Tracks List
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            )
          else
            Consumer<PlayerProvider>(
              builder: (context, player, child) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _artistTracks[index];
                      final isCurrent = player.currentTrack?.id == track.id;
                      final isPlaying = isCurrent && player.isPlaying;
                      final isLoading = isCurrent && player.isLoading;

                      return TrackTile(
                        track: track,
                        isPlaying: isPlaying,
                        isLoading: isLoading,
                        onTap: () {
                          player.playTrack(track, newQueue: _artistTracks);
                        },
                      );
                    },
                    childCount: _artistTracks.length,
                  ),
                );
              },
            ),

          // Discography / Albums Section
          if (_albums.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  'Albums & Singles',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _albums.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final album = _albums[index];
                    return SizedBox(
                      width: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderDivider),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.album_rounded,
                                color: AppColors.secondaryText,
                                size: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            album.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (album.year != null)
                            Text(
                              album.year!,
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // About / Biography Section
          if (artist.bio != null && artist.bio!.trim().isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 10),
                child: Text(
                  'About',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderDivider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.bio!,
                        maxLines: _isBioExpanded ? 100 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isBioExpanded = !_isBioExpanded;
                          });
                        },
                        child: Text(
                          _isBioExpanded ? 'Show less' : 'Read more',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(
            child: SizedBox(height: 60),
          ),
        ],
      ),
    );
  }
}
