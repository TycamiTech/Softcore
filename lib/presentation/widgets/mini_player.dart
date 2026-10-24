import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  void _openFullScreenPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
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
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final track = player.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final position = player.position;
        final duration = player.duration > Duration.zero
            ? player.duration
            : (track.duration > Duration.zero ? track.duration : const Duration(seconds: 1));
        final progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: GestureDetector(
            onTap: () => _openFullScreenPlayer(context),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDivider, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Thin top progress line
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: AppColors.borderDivider,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryText),
                      ),
                    ),

                    // Content Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          // Small Album Art Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: track.artworkUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: track.artworkUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: AppColors.chipInactive,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: AppColors.secondaryText,
                                          size: 18,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: AppColors.chipInactive,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: AppColors.secondaryText,
                                          size: 18,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.chipInactive,
                                      child: const Icon(
                                        Icons.music_note,
                                        color: AppColors.secondaryText,
                                        size: 18,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Title and Artist
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  player.errorMessage ?? track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: player.errorMessage != null
                                        ? Colors.redAccent
                                        : AppColors.secondaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Play / Pause Toggle Button
                          if (player.isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            )
                          else if (player.errorMessage != null)
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                              onPressed: () => player.retryCurrentTrack(),
                            )
                          else
                            IconButton(
                              icon: Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: AppColors.primaryText,
                                size: 26,
                              ),
                              onPressed: () => player.togglePlayPause(),
                            ),

                          // Next Button
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: AppColors.primaryText,
                              size: 24,
                            ),
                            onPressed: () => player.next(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
