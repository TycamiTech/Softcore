import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:softcore/data/services/saavn_service.dart';
import 'package:softcore/data/services/yt_service.dart';

void main() {
  test('SaavnService anti-remix test for Timeless and One Of The Girls', () async {
    final saavnService = SaavnService();

    final timelessUrl = await saavnService.getAudioUrl('Timeless', 'The Weeknd');
    // Jika Saavn hanya memiliki versi remix/karaoke dari artis pihak ketiga, harus ditolak (null)
    if (timelessUrl != null) {
      expect(timelessUrl.contains('.saavncdn.com/'), isTrue);
      expect(timelessUrl.toLowerCase().contains('remix'), isFalse);
      expect(timelessUrl.toLowerCase().contains('techno'), isFalse);
    }

    final oneOfTheGirlsUrl = await saavnService.getAudioUrl('One Of The Girls', 'The Weeknd, JENNIE & Lily Rose Depp');
    if (oneOfTheGirlsUrl != null) {
      expect(oneOfTheGirlsUrl.contains('.saavncdn.com/'), isTrue);
      expect(oneOfTheGirlsUrl.toLowerCase().contains('remix'), isFalse);
      expect(oneOfTheGirlsUrl.toLowerCase().contains('techno'), isFalse);
    }
  });

  test('YtService downloadToTempFile downloads official audio as valid local file', () async {
    final ytService = YtService();
    const testVideoId = 'f1r0XZLNlGQ'; // One Of The Girls Official Audio

    final fileUri = await ytService.downloadToTempFile(testVideoId);
    expect(fileUri.isScheme('file'), isTrue);

    final file = File(fileUri.toFilePath());
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(10000));

    ytService.dispose();
  });
}
