import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/track_model.dart';
import '../../data/repositories/music_repository.dart';
import '../providers/player_provider.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MusicRepository _repository = MusicRepository();
  Timer? _debounceTimer;

  String _selectedFilter = 'Songs';
  bool _isSearching = false;
  List<TrackModel> _searchResults = _defaultResults;

  final List<String> _filters = const ['Songs', 'Artists', 'Albums'];

  static const List<TrackModel> _defaultResults = [
    TrackModel(
      id: 'diB3hJjB3iE',
      title: 'Nikes',
      artist: 'Frank Ocean',
      album: 'Blonde',
      duration: Duration(minutes: 5, seconds: 14),
      artworkUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'diB3hJjB3iE',
    ),
    TrackModel(
      id: 'L4sbDxR22z4',
      title: 'K.',
      artist: 'Cigarettes After Sex',
      album: 'Cigarettes After Sex',
      duration: Duration(minutes: 5, seconds: 19),
      artworkUrl: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'L4sbDxR22z4',
    ),
    TrackModel(
      id: 'XFkzRNyygfk',
      title: 'Creep',
      artist: 'Radiohead',
      album: 'Pablo Honey',
      duration: Duration(minutes: 3, seconds: 56),
      artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'XFkzRNyygfk',
    ),
    TrackModel(
      id: 'f0Xh921QfQ0',
      title: 'Japanese Denim',
      artist: 'Daniel Caesar',
      album: 'Get You - Single',
      duration: Duration(minutes: 4, seconds: 31),
      artworkUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'f0Xh921QfQ0',
    ),
    TrackModel(
      id: 'bpOSxM0rNPM',
      title: 'Do I Wanna Know?',
      artist: 'Arctic Monkeys',
      album: 'AM',
      duration: Duration(minutes: 4, seconds: 32),
      artworkUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=60',
      youtubeVideoId: 'bpOSxM0rNPM',
    ),
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = _defaultResults;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      setState(() {
        _isSearching = true;
      });
      try {
        final results = await _repository.search(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results.isNotEmpty ? results : _defaultResults;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Screen Title
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Text(
                    'Search',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),

                // Search Bar (#1A1A1A)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.searchBarSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDivider),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 15,
                      ),
                      cursorColor: AppColors.primaryText,
                      decoration: InputDecoration(
                        hintText: 'Search songs, artists...',
                        hintStyle: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 15,
                        ),
                        prefixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.search,
                                color: AppColors.secondaryText,
                                size: 22,
                              ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.secondaryText,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Filter Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryText
                                : AppColors.chipInactive,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryText
                                  : AppColors.borderDivider,
                            ),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.scaffoldBackground
                                  : AppColors.secondaryText,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Results Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text(
                    _searchController.text.trim().isEmpty
                        ? 'Top Results'
                        : 'Search Results',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Dynamic Search Results List
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4, bottom: 20),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final track = _searchResults[index];
                      final isCurrent = player.currentTrack?.id == track.id;
                      final isPlaying = isCurrent && player.isPlaying;
                      final isLoading = isCurrent && player.isLoading;

                      return TrackTile(
                        track: track,
                        isPlaying: isPlaying,
                        isLoading: isLoading,
                        onTap: () {
                          player.playTrack(track, newQueue: _searchResults);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
