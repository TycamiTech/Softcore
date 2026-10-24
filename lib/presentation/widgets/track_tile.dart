import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models/track_model.dart';

class TrackTile extends StatelessWidget {
  final TrackModel track;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTap;

  const TrackTile({
    super.key,
    required this.track,
    this.isPlaying = false,
    this.isLoading = false,
    this.onTap,
  });

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    color: AppColors.cardSurface,
                    child: track.artworkUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: track.artworkUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.chipInactive,
                              child: const Icon(
                                Icons.music_note,
                                color: AppColors.secondaryText,
                                size: 22,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.chipInactive,
                              child: const Icon(
                                Icons.music_note,
                                color: AppColors.secondaryText,
                                size: 22,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.music_note,
                            color: AppColors.secondaryText,
                            size: 22,
                          ),
                  ),
                  if (isLoading)
                    Container(
                      width: 52,
                      height: 52,
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    )
                  else if (isPlaying)
                    Container(
                      width: 52,
                      height: 52,
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: Icon(
                          Icons.equalizer_rounded,
                          color: AppColors.primaryText,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Track Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying ? AppColors.primaryText : AppColors.primaryText,
                      fontSize: 15,
                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Trailing info: duration or spinner
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: AppColors.secondaryText,
                ),
              )
            else
              Text(
                _formatDuration(track.duration),
                style: TextStyle(
                  color: isPlaying ? AppColors.primaryText : AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: isPlaying ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
