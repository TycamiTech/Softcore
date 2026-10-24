import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:softcore/data/services/yt_service.dart';

void main() {
  test('resolveFastAudioUri returns valid stream playable by Oculus Cronet UA', () async {
    final ytService = YtService();
    const testVideoId = 'f1r0XZLNlGQ'; // Video ID Lana Del Rey yang diuji

    final stopwatch = Stopwatch()..start();
    final streamUri = await ytService.resolveFastAudioUri(testVideoId);
    stopwatch.stop();

    expect(streamUri, isNotNull);
    expect(streamUri.toString().contains('googlevideo.com'), isTrue);

    // Test koneksi stream dengan User-Agent Oculus Quest 3 Android VR
    final client = HttpClient();
    final request = await client.getUrl(streamUri);
    request.headers.set(
      'User-Agent',
      'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
    );
    request.headers.set('Range', 'bytes=0-1024');

    final response = await request.close().timeout(const Duration(seconds: 5));
    expect(response.statusCode == 200 || response.statusCode == 206, isTrue);

    await response.drain();
    client.close();
    ytService.dispose();
  });
}
