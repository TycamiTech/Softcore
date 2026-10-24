import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _CachedStream {
  final Uri url;
  final int totalBytes;
  final String mimeType;
  final DateTime createdAt;

  _CachedStream({
    required this.url,
    required this.totalBytes,
    required this.mimeType,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().difference(createdAt).inMinutes > 30;
}

class LocalAudioProxy {
  static final LocalAudioProxy _instance = LocalAudioProxy._internal();
  factory LocalAudioProxy() => _instance;
  LocalAudioProxy._internal();

  HttpServer? _server;
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _CachedStream> _cache = {};

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  /// Memulai server proxy HTTP lokal pada loopback IPv4 (127.0.0.1) dengan port dinamis
  Future<void> start() async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      debugPrint('[LocalAudioProxy] Started local proxy on http://127.0.0.1:${_server!.port}');

      _server!.listen(
        _handleRequest,
        onError: (e) {
          debugPrint('[LocalAudioProxy] Server error: $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[LocalAudioProxy] Failed to bind local server: $e');
    }
  }

  /// Menghasilkan URL proxy lokal dengan ekstensi `.m4a` untuk videoId tertentu
  Uri getProxyUrl(String videoId) {
    final serverPort = port;
    if (serverPort == 0) {
      debugPrint('[LocalAudioProxy] Warning: Local proxy not started yet! Port is 0');
    }
    // URL diakhiri dengan .m4a agar ExoPlayer Android mengenali MP4 container secara instan
    return Uri.parse('http://127.0.0.1:$serverPort/stream/$videoId.m4a');
  }

  /// Menangani request dari ExoPlayer dengan streaming chunked 512KB aman tanpa throttling
  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // Support CORS preflight
    if (request.method == 'OPTIONS') {
      response.headers.set('Access-Control-Allow-Origin', '*');
      response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      response.headers.set('Access-Control-Allow-Headers', '*');
      await response.close();
      return;
    }

    // Ekstraksi videoId dari path /stream/{id}.m4a atau query /stream?id={id}
    String? videoId;
    final path = request.uri.path;

    if (path.startsWith('/stream/')) {
      var rawId = path.substring('/stream/'.length);
      if (rawId.endsWith('.m4a')) {
        rawId = rawId.substring(0, rawId.length - '.m4a'.length);
      } else if (rawId.endsWith('.webm')) {
        rawId = rawId.substring(0, rawId.length - '.webm'.length);
      }
      videoId = rawId;
    } else if (path == '/stream') {
      videoId = request.uri.queryParameters['id'];
    }

    if (videoId == null || videoId.trim().isEmpty) {
      response.statusCode = HttpStatus.notFound;
      response.write('Invalid stream URL pattern');
      await response.close();
      return;
    }

    try {
      // 1. Ambil atau resolve stream info
      final streamInfo = await _getOrResolveStream(videoId.trim());
      final totalBytes = streamInfo.totalBytes;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      var start = 0;
      var end = totalBytes - 1;
      var isRange = false;

      // 2. Parse HTTP Range header (misal: "bytes=0-" atau "bytes=0-1024")
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        isRange = true;
        final rangeParts = rangeHeader.substring(6).split('-');
        if (rangeParts.isNotEmpty && rangeParts[0].isNotEmpty) {
          start = int.tryParse(rangeParts[0]) ?? 0;
        }
        if (rangeParts.length > 1 && rangeParts[1].isNotEmpty) {
          end = int.tryParse(rangeParts[1]) ?? (totalBytes - 1);
        } else {
          // Open-ended Range ("bytes=0-"): ExoPlayer mengharapkan rentang penuh hingga totalBytes - 1
          end = totalBytes - 1;
        }
      }

      if (start >= totalBytes) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$totalBytes');
        await response.close();
        return;
      }

      if (end >= totalBytes) {
        end = totalBytes - 1;
      }

      final contentLength = end - start + 1;

      // 3. Set response headers lengkap untuk ExoPlayer
      response.statusCode = isRange ? HttpStatus.partialContent : HttpStatus.ok;
      response.headers.set(HttpHeaders.contentTypeHeader, streamInfo.mimeType);
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(HttpHeaders.contentLengthHeader, contentLength.toString());
      response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
      response.headers.set('Access-Control-Allow-Origin', '*');
      response.headers.set('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');

      if (isRange) {
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalBytes');
      }

      // Jika request HEAD, selesai di sini
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }

      // 4. Unduh dan teruskan per-chunk 512KB ke ExoPlayer (mencegah throttling dan buffer deadlocks)
      const chunkSize = 512 * 1024; // 512 KB
      var curr = start;

      while (curr <= end) {
        final chunkEnd = (curr + chunkSize - 1) < end ? (curr + chunkSize - 1) : end;

        HttpClient? chunkClient;
        try {
          chunkClient = HttpClient();
          chunkClient.connectionTimeout = const Duration(seconds: 8);

          final chunkReq = await chunkClient.getUrl(streamInfo.url);
          chunkReq.headers.set(HttpHeaders.rangeHeader, 'bytes=$curr-$chunkEnd');
          chunkReq.headers.set(
            HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          );

          final chunkResp = await chunkReq.close();
          await for (final chunkData in chunkResp) {
            response.add(chunkData);
          }
          await response.flush();
          curr = chunkEnd + 1;
        } on SocketException catch (_) {
          // Socket ditutup oleh ExoPlayer (normal saat skip lagu atau selesai membaca header)
          break;
        } on HttpException catch (_) {
          break;
        } catch (e) {
          debugPrint('[LocalAudioProxy] Chunk transfer stopped for $videoId: $e');
          break;
        } finally {
          chunkClient?.close(force: true);
        }
      }

      try {
        await response.close();
      } catch (_) {}
    } catch (e) {
      debugPrint('[LocalAudioProxy] Error processing request for $videoId: $e');
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.write('Proxy error: $e');
        await response.close();
      } catch (_) {}
    }
  }

  /// Mendapatkan manifest stream audio terbaik menggunakan client androidVr & ios
  Future<_CachedStream> _getOrResolveStream(String videoId) async {
    final cached = _cache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached;
    }

    StreamManifest manifest;
    try {
      manifest = await _yt.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.androidVr,
              YoutubeApiClient.ios,
            ],
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 10));
    }

    final audioStreams = manifest.audioOnly;
    if (audioStreams.isEmpty) {
      throw Exception('No audio streams available for $videoId');
    }

    // Prioritaskan M4A/MP4 (itag 140) agar container audio terbaca instan oleh ExoPlayer
    final m4aStreams = audioStreams.where(
      (s) =>
          s.container.name.toLowerCase() == 'mp4' ||
          s.codec.mimeType.contains('mp4') ||
          s.tag == 140,
    ).toList();

    final selected = m4aStreams.isNotEmpty
        ? m4aStreams.last
        : audioStreams.withHighestBitrate();

    final cachedEntry = _CachedStream(
      url: selected.url,
      totalBytes: selected.size.totalBytes,
      mimeType: selected.codec.mimeType.isNotEmpty ? selected.codec.mimeType : 'audio/mp4',
      createdAt: DateTime.now(),
    );

    _cache[videoId] = cachedEntry;
    return cachedEntry;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _cache.clear();
  }

  void dispose() {
    stop();
    _yt.close();
  }
}
