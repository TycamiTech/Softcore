import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioPlayerService {
  AudioPlayerService._internal() {
    // Tangkap error langsung dari playbackEventStream ExoPlayer
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('[AudioPlayerService] PlaybackEvent error caught: $e');
      },
    );
  }

  static final AudioPlayerService _instance = AudioPlayerService._internal();

  factory AudioPlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  /// Memutar audio dari URI dengan penanganan stop(), timeout 15 detik, dan logging komprehensif
  Future<void> playUri(MediaItem item, Uri streamUri) async {
    debugPrint('[AudioPlayerService] 1/3 Resolving URL & preparing playback for: "${item.title}" by ${item.artist} -> $streamUri');

    try {
      // 1. Hentikan pemutaran sebelumnya untuk mencegah race condition atau overlapping
      await _player.stop();

      // 2. Set AudioSource bersih
      debugPrint('[AudioPlayerService] 2/3 Setting AudioSource...');
      final audioSource = AudioSource.uri(
        streamUri,
        tag: item,
      );

      // Gunakan timeout 15 detik pada setAudioSource agar ExoPlayer tidak hang selamanya jika stream bermasalah
      await _player
          .setAudioSource(audioSource)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Audio source loading timed out after 15 seconds: $streamUri'),
          );

      // 3. Mulai playback tanpa await agar Future tidak tertahan sampai akhir lagu
      debugPrint('[AudioPlayerService] 3/3 Starting playback...');
      unawaited(_player.play());
      debugPrint('[AudioPlayerService] Playback triggered successfully for "${item.title}"');
    } catch (e, stack) {
      debugPrint('[AudioPlayerService] Error loading or playing audio: $e\n$stack');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error pausing: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error resuming: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error stopping: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[AudioPlayerService] Error seeking: $e');
    }
  }

  Future<void> setLoopMode(LoopMode loopMode) async {
    try {
      await _player.setLoopMode(loopMode);
    } catch (e) {
      debugPrint('[AudioPlayerService] Error setting loop mode: $e');
    }
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    try {
      await _player.setShuffleModeEnabled(enabled);
    } catch (e) {
      debugPrint('[AudioPlayerService] Error setting shuffle mode: $e');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
