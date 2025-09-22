class UriUtils {
  const UriUtils._();

  static Uri resolveToAbsolute(String rawUrl, Uri base) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('URL must not be empty');
    }
    final uri = Uri.parse(trimmed);
    if (uri.hasScheme) {
      return normalize(uri);
    }
    return normalize(base.resolveUri(uri));
  }

  static Uri normalize(Uri uri) {
    final sanitized = uri.removeFragment();
    if (sanitized.query.isEmpty) {
      return sanitized;
    }
    final sortedEntries = sanitized.queryParametersAll.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer();
    for (final entry in sortedEntries) {
      final values = List<String>.from(entry.value)
        ..sort((a, b) => a.compareTo(b));
      for (final value in values) {
        if (buffer.isNotEmpty) {
          buffer.write('&');
        }
        buffer
          ..write(Uri.encodeQueryComponent(entry.key))
          ..write('=')
          ..write(Uri.encodeQueryComponent(value));
      }
      if (values.isEmpty) {
        if (buffer.isNotEmpty) {
          buffer.write('&');
        }
        buffer.write(Uri.encodeQueryComponent(entry.key));
      }
    }
    return sanitized.replace(query: buffer.toString());
  }
}

extension on Uri {
  Uri removeFragment() => replace(fragment: null);
}
