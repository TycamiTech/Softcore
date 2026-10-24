import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:softcore/core/local_audio_proxy.dart';

void main() {
  test('LocalAudioProxy serves audio with .m4a path, safe chunking, and RAM cache', () async {
    final proxy = LocalAudioProxy();
    await proxy.start();
    expect(proxy.isRunning, isTrue);
    expect(proxy.port, greaterThan(0));

    final localUrl = proxy.getProxyUrl('ggG9ySCChYw');
    expect(localUrl.path.endsWith('.m4a'), isTrue);

    final client = HttpClient();

    // 1. Uji Open-ended Range request ExoPlayer: "bytes=0-"
    final req1 = await client.getUrl(localUrl);
    req1.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
    final resp1 = await req1.close();

    expect(resp1.statusCode, HttpStatus.partialContent);
    expect(resp1.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
    expect(resp1.headers.value(HttpHeaders.contentRangeHeader), startsWith('bytes 0-'));
    expect(resp1.headers.value(HttpHeaders.contentTypeHeader), contains('audio/'));

    // ExoPlayer hanya membaca beberapa kilobyte awal untuk memverifikasi ftyp box
    final initialChunk = await resp1.first;
    expect(initialChunk.isNotEmpty, isTrue);

    // 2. Uji explicit probe: "bytes=0-1024"
    final req2 = await client.getUrl(localUrl);
    req2.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1024');
    final resp2 = await req2.close();

    expect(resp2.statusCode, HttpStatus.partialContent);
    expect(resp2.headers.value(HttpHeaders.contentRangeHeader), startsWith('bytes 0-1024/'));

    final bytes2 = await resp2.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
    expect(bytes2.length, 1025);

    client.close(force: true);
    await proxy.stop();
  }, timeout: const Timeout(Duration(seconds: 25)));
}
