import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

enum MediaType { image, video, streaming }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    required this.url,
    required this.normalizedUrl,
    this.width,
    this.height,
    this.bytes,
    this.contentLength,
    this.thumbnailUrl,
    this.isSelected = false,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final rawBytes = json['bytes'] as String?;
    return MediaItem(
      id: json['id'] as String,
      type: _mediaTypeFromJson(json['type'] as String),
      url: Uri.parse(json['url'] as String),
      normalizedUrl: Uri.parse(json['normalizedUrl'] as String),
      width: json['width'] as int?,
      height: json['height'] as int?,
      bytes: rawBytes == null ? null : base64Decode(rawBytes),
      contentLength: json['contentLength'] as int?,
      thumbnailUrl: (json['thumbnailUrl'] as String?)?.let(Uri.parse),
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  final String id;
  final MediaType type;
  final Uri url;
  final Uri normalizedUrl;
  final int? width;
  final int? height;
  final Uint8List? bytes;
  final int? contentLength;
  final Uri? thumbnailUrl;
  final bool isSelected;

  MediaItem copyWith({
    String? id,
    MediaType? type,
    Uri? url,
    Uri? normalizedUrl,
    int? width,
    int? height,
    Uint8List? bytes,
    int? contentLength,
    Uri? thumbnailUrl,
    bool? isSelected,
  }) {
    return MediaItem(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
      normalizedUrl: normalizedUrl ?? this.normalizedUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
      contentLength: contentLength ?? this.contentLength,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'url': url.toString(),
        'normalizedUrl': normalizedUrl.toString(),
        'width': width,
        'height': height,
        'bytes': bytes == null ? null : base64Encode(bytes!),
        'contentLength': contentLength,
        'thumbnailUrl': thumbnailUrl?.toString(),
        'isSelected': isSelected,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MediaItem &&
        other.id == id &&
        other.type == type &&
        other.url == url &&
        other.normalizedUrl == normalizedUrl &&
        other.width == width &&
        other.height == height &&
        listEquals(other.bytes, bytes) &&
        other.contentLength == contentLength &&
        other.thumbnailUrl == thumbnailUrl &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        url,
        normalizedUrl,
        width,
        height,
        bytes == null ? null : base64Encode(bytes!),
        contentLength,
        thumbnailUrl,
        isSelected,
      );
}

MediaType _mediaTypeFromJson(String raw) {
  return MediaType.values.firstWhere(
    (type) => type.name == raw,
    orElse: () => MediaType.image,
  );
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}
