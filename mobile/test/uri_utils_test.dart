import 'package:flutter_test/flutter_test.dart';

import 'package:butterknife_app/core/utils/uri_utils.dart';

void main() {
  group('UriUtils', () {
    test('resolves relative URLs', () {
      final base = Uri.parse('https://example.com/path/page');
      final resolved = UriUtils.resolveToAbsolute('../image.png', base);
      expect(resolved.toString(), 'https://example.com/image.png');
    });

    test('normalizes query parameters order', () {
      final uri = Uri.parse('https://example.com?a=1&b=2&a=3#hash');
      final normalized = UriUtils.normalize(uri);
      expect(normalized.toString(), 'https://example.com?a=1&a=3&b=2');
    });
  });
}
