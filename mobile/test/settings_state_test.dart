import 'package:flutter_test/flutter_test.dart';

import 'package:butterknife_app/features/settings/models/settings_state.dart';

void main() {
  group('SettingsState', () {
    test('copyWith returns new instance', () {
      const state = SettingsState.initial();
      final updated = state.copyWith(minImageBytes: 20480, includeGif: false);
      expect(updated.minImageBytes, 20480);
      expect(updated.includeGif, isFalse);
      expect(state.minImageBytes, isNot(20480));
      expect(state.includeGif, isTrue);
    });

    test('serializes to and from json', () {
      final state = SettingsState.initial().copyWith(
        imageSaveDirectory: '/tmp/images',
        videoSaveDirectory: '/tmp/videos',
      );
      final json = state.toJson();
      final parsed = SettingsState.fromJson(json);
      expect(parsed, equals(state));
    });

    test('copyWith updates download directories', () {
      const state = SettingsState.initial();
      final updated = state.copyWith(
        imageSaveDirectory: '/data/images',
        videoSaveDirectory: '/data/videos',
      );
      expect(updated.imageSaveDirectory, '/data/images');
      expect(updated.videoSaveDirectory, '/data/videos');
      final cleared = updated.copyWith(
        imageSaveDirectory: null,
        videoSaveDirectory: null,
      );
      expect(cleared.imageSaveDirectory, isNull);
      expect(cleared.videoSaveDirectory, isNull);
    });
  });
}
