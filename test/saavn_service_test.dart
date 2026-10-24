import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:softcore/data/services/saavn_service.dart';

void main() {
  test('SaavnService resolves direct Akamai CDN URL for popular song and returns valid HTTP 200/206', () async {
    final saavnService = SaavnService();

    final audioUrl = await saavnService.getAudioUrl('Softcore', 'The Neighbourhood');

    expect(audioUrl, isNotNull);
    expect(audioUrl, startsWith('https://'));
    expect(audioUrl, contains('.saavncdn.com/'));

    final client = HttpClient();
    final req = await client.openUrl('HEAD', Uri.parse(audioUrl!));
    final resp = await req.close();

    expect(resp.statusCode == HttpStatus.ok || resp.statusCode == HttpStatus.partialContent, isTrue);
    expect(resp.contentLength, greaterThan(1000000)); // Sekitar 2-8 MB

    client.close();
  }, timeout: const Timeout(Duration(seconds: 25)));
}
