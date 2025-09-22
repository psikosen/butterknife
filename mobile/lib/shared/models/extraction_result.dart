import 'media_item.dart';

class SkippedStats {
  const SkippedStats({
    this.faviconCount = 0,
    this.smallAssetCount = 0,
    this.streamingCount = 0,
  });

  factory SkippedStats.fromJson(Map<String, dynamic> json) => SkippedStats(
        faviconCount: json['faviconCount'] as int? ?? 0,
        smallAssetCount: json['smallAssetCount'] as int? ?? 0,
        streamingCount: json['streamingCount'] as int? ?? 0,
      );

  final int faviconCount;
  final int smallAssetCount;
  final int streamingCount;

  SkippedStats copyWith({
    int? faviconCount,
    int? smallAssetCount,
    int? streamingCount,
  }) =>
      SkippedStats(
        faviconCount: faviconCount ?? this.faviconCount,
        smallAssetCount: smallAssetCount ?? this.smallAssetCount,
        streamingCount: streamingCount ?? this.streamingCount,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'faviconCount': faviconCount,
        'smallAssetCount': smallAssetCount,
        'streamingCount': streamingCount,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SkippedStats &&
        other.faviconCount == faviconCount &&
        other.smallAssetCount == smallAssetCount &&
        other.streamingCount == streamingCount;
  }

  @override
  int get hashCode => Object.hash(faviconCount, smallAssetCount, streamingCount);
}

class ExtractionResult {
  const ExtractionResult({
    required this.pageUrl,
    required this.found,
    required this.skipped,
  });

  factory ExtractionResult.fromJson(Map<String, dynamic> json) => ExtractionResult(
        pageUrl: Uri.parse(json['pageUrl'] as String),
        found: (json['found'] as List<dynamic>)
            .map((dynamic item) => MediaItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        skipped: SkippedStats.fromJson(json['skipped'] as Map<String, dynamic>),
      );

  final Uri pageUrl;
  final List<MediaItem> found;
  final SkippedStats skipped;

  ExtractionResult copyWith({
    Uri? pageUrl,
    List<MediaItem>? found,
    SkippedStats? skipped,
  }) =>
      ExtractionResult(
        pageUrl: pageUrl ?? this.pageUrl,
        found: found ?? this.found,
        skipped: skipped ?? this.skipped,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pageUrl': pageUrl.toString(),
        'found': found.map((item) => item.toJson()).toList(),
        'skipped': skipped.toJson(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ExtractionResult &&
        other.pageUrl == pageUrl &&
        _listEquals(other.found, found) &&
        other.skipped == skipped;
  }

  @override
  int get hashCode => Object.hash(pageUrl, Object.hashAll(found), skipped);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
