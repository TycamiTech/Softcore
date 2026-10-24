import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/track_model.dart';
import '../../data/services/local_db_service.dart';
import '../providers/player_provider.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final LocalDbService _localDbService = LocalDbService();
  int _selectedTabIndex = 0; // 0 = Favorites, 1 = Recently Played

  List<TrackModel> _favorites = [];
  List<TrackModel> _recentlyPlayed = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final favs = await _localDbService.getFavorites();
      final recents = await _localDbService.getRecentlyPlayed();

      if (mounted) {
        setState(() {
          _favorites = favs;
          _recentlyPlayed = recents;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearRecentlyPlayed() async {
    await _localDbService.clearRecentlyPlayed();
    await _loadLibraryData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  if (_selectedTabIndex == 1 && _recentlyPlayed.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearRecentlyPlayed,
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.secondaryText),
                      label: const Text(
                        'Clear',
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),

            // Tab Selector Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildTabChip(label: 'Favorites (${_favorites.length})', index: 0),
                  const SizedBox(width: 10),
                  _buildTabChip(label: 'Recently Played', index: 1),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content List
            Expanded(
              child: Consumer<PlayerProvider>(
                builder: (context, player, child) {
                  final currentTracks = _selectedTabIndex == 0 ? _favorites : _recentlyPlayed;

                  if (_isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryText,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (currentTracks.isEmpty) {
                    return _buildEmptyState(
                      icon: _selectedTabIndex == 0 ? Icons.favorite_border : Icons.history,
                      title: _selectedTabIndex == 0
                          ? 'No favorites yet'
                          : 'No listening history',
                      subtitle: _selectedTabIndex == 0
                          ? 'Heart your favorite tracks to build your personal offline collection.'
                          : 'Tracks you play will automatically appear here.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadLibraryData,
                    color: AppColors.primaryText,
                    backgroundColor: AppColors.cardSurface,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: currentTracks.length,
                      padding: const EdgeInsets.only(bottom: 120),
                      itemBuilder: (context, index) {
                        final track = currentTracks[index];
                        final isCurrentlyPlaying = player.currentTrack?.id == track.id && player.isPlaying;
                        final isCurrentTrackLoading = player.currentTrack?.id == track.id && player.isLoading;

                        return TrackTile(
                          track: track,
                          isPlaying: isCurrentlyPlaying,
                          isLoading: isCurrentTrackLoading,
                          onTap: () {
                            player.playTrack(track, newQueue: currentTracks);
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip({required String label, required int index}) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTabIndex != index) {
          setState(() {
            _selectedTabIndex = index;
          });
          _loadLibraryData();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryText : AppColors.chipInactive,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.primaryText,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.secondaryText,
              size: 54,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
