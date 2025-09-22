class SettingsState {
  const SettingsState({
    required this.minImageBytes,
    required this.useDesktopUserAgent,
    required this.concurrentDownloads,
    required this.includeSvg,
    required this.includeGif,
    required this.includeAutoplayThumbnails,
    this.imageSaveDirectory,
    this.videoSaveDirectory,
  });

  factory SettingsState.initial() => const SettingsState(
        minImageBytes: 10240,
        useDesktopUserAgent: false,
        concurrentDownloads: 3,
        includeSvg: true,
        includeGif: true,
        includeAutoplayThumbnails: false,
        imageSaveDirectory: null,
        videoSaveDirectory: null,
      );

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
        minImageBytes: json['minImageBytes'] as int? ?? 10240,
        useDesktopUserAgent: json['useDesktopUserAgent'] as bool? ?? false,
        concurrentDownloads: json['concurrentDownloads'] as int? ?? 3,
        includeSvg: json['includeSvg'] as bool? ?? true,
        includeGif: json['includeGif'] as bool? ?? true,
        includeAutoplayThumbnails: json['includeAutoplayThumbnails'] as bool? ?? false,
        imageSaveDirectory: json['imageSaveDirectory'] as String?,
        videoSaveDirectory: json['videoSaveDirectory'] as String?,
      );

  final int minImageBytes;
  final bool useDesktopUserAgent;
  final int concurrentDownloads;
  final bool includeSvg;
  final bool includeGif;
  final bool includeAutoplayThumbnails;
  final String? imageSaveDirectory;
  final String? videoSaveDirectory;

  SettingsState copyWith({
    int? minImageBytes,
    bool? useDesktopUserAgent,
    int? concurrentDownloads,
    bool? includeSvg,
    bool? includeGif,
    bool? includeAutoplayThumbnails,
    Object? imageSaveDirectory = _sentinel,
    Object? videoSaveDirectory = _sentinel,
  }) =>
      SettingsState(
        minImageBytes: minImageBytes ?? this.minImageBytes,
        useDesktopUserAgent: useDesktopUserAgent ?? this.useDesktopUserAgent,
        concurrentDownloads: concurrentDownloads ?? this.concurrentDownloads,
        includeSvg: includeSvg ?? this.includeSvg,
        includeGif: includeGif ?? this.includeGif,
        includeAutoplayThumbnails:
            includeAutoplayThumbnails ?? this.includeAutoplayThumbnails,
        imageSaveDirectory: imageSaveDirectory == _sentinel
            ? this.imageSaveDirectory
            : imageSaveDirectory as String?,
        videoSaveDirectory: videoSaveDirectory == _sentinel
            ? this.videoSaveDirectory
            : videoSaveDirectory as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'minImageBytes': minImageBytes,
        'useDesktopUserAgent': useDesktopUserAgent,
        'concurrentDownloads': concurrentDownloads,
        'includeSvg': includeSvg,
        'includeGif': includeGif,
        'includeAutoplayThumbnails': includeAutoplayThumbnails,
        'imageSaveDirectory': imageSaveDirectory,
        'videoSaveDirectory': videoSaveDirectory,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SettingsState &&
        other.minImageBytes == minImageBytes &&
        other.useDesktopUserAgent == useDesktopUserAgent &&
        other.concurrentDownloads == concurrentDownloads &&
        other.includeSvg == includeSvg &&
        other.includeGif == includeGif &&
        other.includeAutoplayThumbnails == includeAutoplayThumbnails &&
        other.imageSaveDirectory == imageSaveDirectory &&
        other.videoSaveDirectory == videoSaveDirectory;
  }

  @override
  int get hashCode => Object.hash(
        minImageBytes,
        useDesktopUserAgent,
        concurrentDownloads,
        includeSvg,
        includeGif,
        includeAutoplayThumbnails,
        imageSaveDirectory,
        videoSaveDirectory,
      );
}

const Object _sentinel = Object();
