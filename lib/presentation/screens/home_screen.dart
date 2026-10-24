import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/artist_model.dart';
import '../../data/models/track_model.dart';
import '../../data/repositories/music_repository.dart';
import '../providers/player_provider.dart';
import '../widgets/track_tile.dart';
import 'artist_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MusicRepository _repository = MusicRepository();
  List<TrackModel> _trendingTracks = _westernTrendingTracks;
  bool _isLoading = false;
  bool _hasError = false;

  static const List<ArtistModel> _popularArtists = [
    ArtistModel(
      name: 'The Weeknd',
      fanartUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'The Neighbourhood',
      fanartUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Billie Eilish',
      fanartUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Arctic Monkeys',
      fanartUrl: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Frank Ocean',
      fanartUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Lana Del Rey',
      fanartUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Post Malone',
      fanartUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'SZA',
      fanartUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Kendrick Lamar',
      fanartUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Joji',
      fanartUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Steve Lacy',
      fanartUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=500&auto=format&fit=crop&q=60',
    ),
    ArtistModel(
      name: 'Daft Punk',
      fanartUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60',
    ),
  ];

  static const List<TrackModel> _westernTrendingTracks = [
    TrackModel(
      id: 'ggG9ySCChYw',
      title: 'Softcore',
      artist: 'The Neighbourhood',
      album: 'Hard To Imagine The Neighbourhood Ever Changing',
      duration: Duration(minutes: 3, seconds: 30),
      artworkUrl: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'ggG9ySCChYw',
    ),
    TrackModel(
      id: 'GCdwKhTtNNw',
      title: 'Sweater Weather',
      artist: 'The Neighbourhood',
      album: 'I Love You.',
      duration: Duration(minutes: 4, seconds: 0),
      artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'GCdwKhTtNNw',
    ),
    TrackModel(
      id: '516pUpt_nL0',
      title: 'Timeless',
      artist: 'The Weeknd, Playboi Carti',
      album: 'Hurry Up Tomorrow',
      duration: Duration(minutes: 4, seconds: 16),
      artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: '516pUpt_nL0',
    ),
    TrackModel(
      id: '4NRXx6U8ABQ',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      duration: Duration(minutes: 3, seconds: 20),
      artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: '4NRXx6U8ABQ',
    ),
    TrackModel(
      id: 'V9PVRfjEBTI',
      title: 'BIRDS OF A FEATHER',
      artist: 'Billie Eilish',
      album: 'HIT ME HARD AND SOFT',
      duration: Duration(minutes: 3, seconds: 15),
      artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'V9PVRfjEBTI',
    ),
    TrackModel(
      id: 'r4l9bFqgMaQ',
      title: 'Pink + White',
      artist: 'Frank Ocean',
      album: 'Blonde',
      duration: Duration(minutes: 3, seconds: 4),
      artworkUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'r4l9bFqgMaQ',
    ),
    TrackModel(
      id: 'nyuo9-OjNNg',
      title: 'I Wanna Be Yours',
      artist: 'Arctic Monkeys',
      album: 'AM',
      duration: Duration(minutes: 3, seconds: 4),
      artworkUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'nyuo9-OjNNg',
    ),
    TrackModel(
      id: 'qU9mHegkTc4',
      title: '505',
      artist: 'Arctic Monkeys',
      album: 'Favourite Worst Nightmare',
      duration: Duration(minutes: 4, seconds: 13),
      artworkUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'qU9mHegkTc4',
    ),
    TrackModel(
      id: 'cE6wxJpnkt4',
      title: 'Video Games',
      artist: 'Lana Del Rey',
      album: 'Born to Die',
      duration: Duration(minutes: 4, seconds: 42),
      artworkUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'cE6wxJpnkt4',
    ),
    TrackModel(
      id: 'LDY_Xyxz8yA',
      title: 'Snooze',
      artist: 'SZA',
      album: 'SOS',
      duration: Duration(minutes: 3, seconds: 21),
      artworkUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'LDY_Xyxz8yA',
    ),
    TrackModel(
      id: 'FvOpPeKSf_4',
      title: 'Glimpse of Us',
      artist: 'Joji',
      album: 'SMITHEREENS',
      duration: Duration(minutes: 3, seconds: 53),
      artworkUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'FvOpPeKSf_4',
    ),
    TrackModel(
      id: 'VF-FGy_KGvo',
      title: 'Bad Habit',
      artist: 'Steve Lacy',
      album: 'Gemini Rights',
      duration: Duration(minutes: 3, seconds: 52),
      artworkUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'VF-FGy_KGvo',
    ),
    TrackModel(
      id: 'a5uQMwRMHcs',
      title: 'Instant Crush',
      artist: 'Daft Punk ft. Julian Casablancas',
      album: 'Random Access Memories',
      duration: Duration(minutes: 5, seconds: 37),
      artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'a5uQMwRMHcs',
    ),
    TrackModel(
      id: 'wXhTHyIgQ_U',
      title: 'Circles',
      artist: 'Post Malone',
      album: 'Hollywood\'s Bleeding',
      duration: Duration(minutes: 3, seconds: 35),
      artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'wXhTHyIgQ_U',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchTrendingTracks();
  }

  Future<void> _fetchTrendingTracks() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final fetched = await _repository.getTrending();
      if (mounted) {
        setState(() {
          if (fetched.isNotEmpty) {
            _trendingTracks = fetched;
            _hasError = false;
          } else if (_trendingTracks.isEmpty) {
            _hasError = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_trendingTracks.isEmpty) {
            _hasError = true;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openArtistDetail(ArtistModel artist) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ArtistDetailScreen(artist: artist),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, child) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Header: "softcore" branding + subtle action/profile icon
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'softcore',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.0,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.person_outline,
                            color: AppColors.primaryText,
                            size: 22,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.cardSurface,
                            padding: const EdgeInsets.all(8),
                            shape: const CircleBorder(
                              side: BorderSide(color: AppColors.borderDivider),
                            ),
                          ),
                          onPressed: () {
                            // Action/profile placeholder
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Section: Popular Artists
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 14),
                        child: Text(
                          'Popular Artists',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _popularArtists.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 18),
                          itemBuilder: (context, index) {
                            final artist = _popularArtists[index];
                            return GestureDetector(
                              onTap: () => _openArtistDetail(artist),
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.cardSurface,
                                      border: Border.all(
                                        color: AppColors.borderDivider,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: artist.fanartUrl != null &&
                                              artist.fanartUrl!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: artist.fanartUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: AppColors.cardSurface,
                                                child: const Icon(
                                                  Icons.person,
                                                  color: AppColors.secondaryText,
                                                  size: 28,
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: AppColors.cardSurface,
                                                child: const Icon(
                                                  Icons.person,
                                                  color: AppColors.secondaryText,
                                                  size: 28,
                                                ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              color: AppColors.secondaryText,
                                              size: 28,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 74,
                                    child: Text(
                                      artist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.secondaryText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),

                // Section: Trending Tracks Header with loading indicator
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Western Hits Trending',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: AppColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Section: Trending Tracks List / Error / Loading States
                if (_hasError && _trendingTracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Gagal memuat lagu. Coba lagi',
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _fetchTrendingTracks,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryText,
                                backgroundColor: AppColors.cardSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: AppColors.borderDivider),
                                ),
                              ),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _trendingTracks[index];
                        final isCurrent = player.currentTrack?.id == track.id;
                        final isPlaying = isCurrent && player.isPlaying;
                        final isLoading = isCurrent && player.isLoading;

                        return TrackTile(
                          track: track,
                          isPlaying: isPlaying,
                          isLoading: isLoading,
                          onTap: () {
                            player.playTrack(track, newQueue: _trendingTracks);
                          },
                        );
                      },
                      childCount: _trendingTracks.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
