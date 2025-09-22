import 'package:flutter_test/flutter_test.dart';

import 'package:butterknife_app/shared/models/extraction_result.dart';
import 'package:butterknife_app/shared/models/media_item.dart';

void main() {
  group('ExtractionResult', () {
    test('serializes and deserializes correctly', () {
      final item = MediaItem(
        id: 'a',
        type: MediaType.image,
        url: Uri.parse('https://example.com/a.jpg'),
        normalizedUrl: Uri.parse('https://example.com/a.jpg'),
      );
      final result = ExtractionResult(
        pageUrl: Uri.parse('https://example.com'),
        found: [item],
        skipped: const SkippedStats(faviconCount: 1, smallAssetCount: 2),
      );

      final json = result.toJson();
      final roundTrip = ExtractionResult.fromJson(json);

      expect(roundTrip.pageUrl, result.pageUrl);
      expect(roundTrip.found, result.found);
      expect(roundTrip.skipped, result.skipped);
    });
  });
}
