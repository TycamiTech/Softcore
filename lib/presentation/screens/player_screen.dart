import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../providers/player_provider.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, child) {
            final track = player.currentTrack;
            if (track == null) {
              return Center(
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              );
            }

            final isFavorite = player.isFavorite(track.id);
            final position = player.position;
            final duration = player.duration > Duration.zero
                ? player.duration
                : (track.duration > Duration.zero ? track.duration : const Duration(seconds: 1));

            final progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  // Top Bar: Dismiss button on left, subtle title/options on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primaryText,
                          size: 32,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'PLAYING FROM SOFTCORE',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.primaryText,
                          size: 24,
                        ),
                        onPressed: () {
                          // Options sheet or placeholder
                        },
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Center Artwork with soft monochromatic ambient glow & shadow
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: MediaQuery.of(context).size.width * 0.8,
                      constraints: const BoxConstraints(maxWidth: 340, maxHeight: 340),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.07),
                            blurRadius: 50,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.9),
                            blurRadius: 25,
                            spreadRadius: -4,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: track.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: track.artworkUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.cardSurface,
                                  child: const Center(
                                    child: Icon(
                                      Icons.music_note,
                                      color: AppColors.secondaryText,
                                      size: 54,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.cardSurface,
                                  child: const Center(
                                    child: Icon(
                                      Icons.music_note,
                                      color: AppColors.secondaryText,
                                      size: 54,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.cardSurface,
                                child: const Center(
                                  child: Icon(
                                    Icons.music_note,
                                    color: AppColors.secondaryText,
                                    size: 54,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Track Metadata: Bold white title, muted grey artist name, favorite button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? AppColors.primaryText : AppColors.secondaryText,
                          size: 26,
                        ),
                        onPressed: () {
                          player.toggleFavorite(track.id, track);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Seek Bar: Thin progress slider + position & remaining/total
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: AppColors.primaryText,
                          inactiveTrackColor: AppColors.borderDivider,
                          thumbColor: AppColors.primaryText,
                          overlayColor: Colors.white.withValues(alpha: 0.12),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (newVal) {
                            final seekTarget = Duration(
                              milliseconds: (newVal * duration.inMilliseconds).round(),
                            );
                            player.seek(seekTarget);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTime(position),
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '-${_formatTime(duration - position > Duration.zero ? duration - position : Duration.zero)}',
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Playback Controls: Shuffle, Previous, Play/Pause, Next, Repeat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: player.isShuffle
                              ? AppColors.primaryText
                              : AppColors.secondaryText,
                          size: 22,
                        ),
                        onPressed: () => player.toggleShuffle(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: AppColors.primaryText,
                          size: 34,
                        ),
                        onPressed: () => player.previous(),
                      ),
                      GestureDetector(
                        onTap: () => player.togglePlayPause(),
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryText,
                          ),
                          child: Center(
                            child: player.isLoading
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.8,
                                      color: AppColors.scaffoldBackground,
                                    ),
                                  )
                                : Icon(
                                    player.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: AppColors.scaffoldBackground,
                                    size: 36,
                                  ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: AppColors.primaryText,
                          size: 34,
                        ),
                        onPressed: () => player.next(),
                      ),
                      IconButton(
                        icon: Icon(
                          player.isRepeat
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: player.isRepeat
                              ? AppColors.primaryText
                              : AppColors.secondaryText,
                          size: 22,
                        ),
                        onPressed: () => player.toggleRepeat(),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
