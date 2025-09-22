import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:butterknife_app/shared/models/media_item.dart';

void main() {
  group('MediaItem', () {
    test('serializes and deserializes with bytes', () {
      final item = MediaItem(
        id: 'id-1',
        type: MediaType.image,
        url: Uri.parse('https://example.com/image.png'),
        normalizedUrl: Uri.parse('https://example.com/image.png'),
        width: 200,
        height: 100,
        bytes: Uint8List.fromList(utf8.encode('pixels')),
        contentLength: 6,
        thumbnailUrl: Uri.parse('https://example.com/thumb.png'),
        isSelected: true,
      );

      final roundTrip = MediaItem.fromJson(item.toJson());
      expect(roundTrip, equals(item));
      expect(roundTrip.bytes, isNotNull);
      expect(roundTrip.bytes, equals(item.bytes));
    });

    test('copyWith updates fields immutably', () {
      final item = MediaItem(
        id: 'id-1',
        type: MediaType.image,
        url: Uri.parse('https://example.com/a.jpg'),
        normalizedUrl: Uri.parse('https://example.com/a.jpg'),
      );

      final updated = item.copyWith(isSelected: true, width: 640);
      expect(updated.isSelected, isTrue);
      expect(updated.width, 640);
      expect(item.isSelected, isFalse);
      expect(item.width, isNull);
    });
  });
}
