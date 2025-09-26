import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/result/app_result.dart';
import '../../../shared/models/media_item.dart';
import '../../download/controllers/download_controller.dart';
import '../../extract/controllers/extraction_controller.dart';
import '../../settings/controllers/settings_controller.dart';
import '../controllers/browser_controller.dart';

class BrowserView extends StatefulWidget {
  const BrowserView({super.key});

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> {
  late final BrowserController _browserController;
  late final ExtractionController _extractionController;
  late final DownloadController _downloadController;
  late final SettingsController _settingsController;
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _browserController = Get.find<BrowserController>();
    _extractionController = Get.find<ExtractionController>();
    _downloadController = Get.find<DownloadController>();
    _settingsController = Get.find<SettingsController>();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _browserController.isLoading.value = true;
            _browserController.updateCurrentUrlFromWebView(url);
          },
          onPageFinished: (url) {
            _browserController.isLoading.value = false;
            _browserController.updateCurrentUrlFromWebView(url);
          },
          onWebResourceError: (error) {
            final appError = UnknownError(
              'Failed to load page',
              cause: error,
            );
            _extractionController.recordError(appError);
          },
        ),
      );
    _browserController.attachWebViewController(_webViewController);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Butter Knife Browser'),
        actions: [
          Obx(() {
            final isVisible = _browserController.showControls.value;
            return IconButton(
              icon: Icon(isVisible ? Icons.menu_open : Icons.menu),
              tooltip: isVisible ? 'Hide address bar' : 'Show address bar',
              onPressed: _browserController.toggleControlsVisibility,
            );
          }),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Show bookmarks',
            onPressed: _showFavorites,
          ),
          Obx(() {
            final hasUrl = _browserController.currentUrl.value != null;
            return IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy current link',
              onPressed: hasUrl ? _copyCurrentLink : null,
            );
          }),
          Obx(() {
            final ready = _settingsController.isReady.value;
            return IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Download destinations',
              onPressed: ready ? _openDownloadSettings : null,
            );
          }),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController.reload(),
          ),
        ],
      ),
      floatingActionButton: Obx(() {
        final selectedCount = _extractionController.selectedItems.length;
        if (selectedCount == 0) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton.extended(
          onPressed: _downloadSelected,
          icon: const Icon(Icons.download),
          label: Text('Download $selectedCount'),
        );
      }),
      body: Column(
        children: [
          Obx(() {
            if (_browserController.showControls.value) {
              return _UrlInputBar(controller: _browserController);
            }
            return const SizedBox.shrink();
          }),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _webViewController),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Obx(() {
                          if (_browserController.isLoading.value) {
                            return const LinearProgressIndicator();
                          }
                          return const SizedBox.shrink();
                        }),
                      ),
                      Obx(() {
                        if (!_extractionController.isProcessing.value) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          color: Colors.black.withOpacity(0.6),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Processing page…',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 1,
                  child: _ExtractionPanel(
                    extractionController: _extractionController,
                    downloadController: _downloadController,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFavorites() async {
    AppLogger.logInfo(
      filename: 'lib/features/browser/views/browser_view.dart',
      classname: '_BrowserViewState',
      function: '_showFavorites',
      systemSection: 'browser',
      message: 'Opening favorites sheet',
    );
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              final favorites =
                  _browserController.favorites.toList(growable: false);
              if (favorites.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('No bookmarked pages yet.'),
                  ),
                );
              }
              return SizedBox(
                height: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bookmarked pages',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemBuilder: (context, index) {
                          final url = favorites[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            title: Text(
                              url.toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              AppLogger.logInfo(
                                filename:
                                    'lib/features/browser/views/browser_view.dart',
                                classname: '_BrowserViewState',
                                function: '_showFavorites',
                                systemSection: 'browser',
                                message: 'Opening bookmarked URL $url',
                              );
                              try {
                                await _browserController.openFromFavorites(url);
                              } catch (_) {
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to open ${url.toString()}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: favorites.length,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _copyCurrentLink() async {
    final url = _browserController.currentUrl.value;
    if (url == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a page before copying the link.'),
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: url.toString()));
    AppLogger.logInfo(
      filename: 'lib/features/browser/views/browser_view.dart',
      classname: '_BrowserViewState',
      function: '_copyCurrentLink',
      systemSection: 'browser',
      message: 'Copied current URL $url to clipboard',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _openDownloadSettings() async {
    AppLogger.logInfo(
      filename: 'lib/features/browser/views/browser_view.dart',
      classname: '_BrowserViewState',
      function: '_openDownloadSettings',
      systemSection: 'settings',
      message: 'Opening download destinations sheet',
    );
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _DownloadSettingsSheet(
        settingsController: _settingsController,
        onPickImageDirectory: () => _pickDirectory(
          mediaType: 'image',
          onSelected: (path) => _settingsController.setImageSaveDirectory(path),
        ),
        onPickVideoDirectory: () => _pickDirectory(
          mediaType: 'video',
          onSelected: (path) => _settingsController.setVideoSaveDirectory(path),
        ),
        onClearImageDirectory: () => _clearDirectory(isVideo: false),
        onClearVideoDirectory: () => _clearDirectory(isVideo: true),
      ),
    );
  }

  Future<void> _pickDirectory({
    required String mediaType,
    required Future<void> Function(String path) onSelected,
  }) async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select $mediaType download directory',
      );
      if (path == null) {
        AppLogger.logInfo(
          filename: 'lib/features/browser/views/browser_view.dart',
          classname: '_BrowserViewState',
          function: '_pickDirectory',
          systemSection: 'settings',
          message: 'User cancelled selecting $mediaType directory',
        );
        return;
      }
      await onSelected(path);
      AppLogger.logInfo(
        filename: 'lib/features/browser/views/browser_view.dart',
        classname: '_BrowserViewState',
        function: '_pickDirectory',
        systemSection: 'settings',
        message: 'Selected default $mediaType directory: $path',
      );
    } catch (error, stackTrace) {
      AppLogger.logError(
        filename: 'lib/features/browser/views/browser_view.dart',
        classname: '_BrowserViewState',
        function: '_pickDirectory',
        systemSection: 'settings',
        message: 'Failed to pick $mediaType directory',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick $mediaType directory'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearDirectory({required bool isVideo}) async {
    if (isVideo) {
      await _settingsController.setVideoSaveDirectory(null);
      AppLogger.logInfo(
        filename: 'lib/features/browser/views/browser_view.dart',
        classname: '_BrowserViewState',
        function: '_clearDirectory',
        systemSection: 'settings',
        message: 'Cleared default video directory',
      );
    } else {
      await _settingsController.setImageSaveDirectory(null);
      AppLogger.logInfo(
        filename: 'lib/features/browser/views/browser_view.dart',
        classname: '_BrowserViewState',
        function: '_clearDirectory',
        systemSection: 'settings',
        message: 'Cleared default image directory',
      );
    }
  }

  Future<void> _downloadSelected() async {
    final selected = _extractionController.selectedItems;
    for (final item in selected) {
      final result = await _downloadController.download(item);
      result.when(
        success: (downloaded) {
          _extractionController.applyDownloadedItem(downloaded);
        },
        failure: (error) {
          AppLogger.logError(
            filename: 'lib/features/browser/views/browser_view.dart',
            classname: '_BrowserViewState',
            function: '_downloadSelected',
            systemSection: 'download',
            message: 'Failed to download ${item.normalizedUrl}',
            error: error,
          );
          Get.snackbar(
            'Download failed',
            error.message,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
          );
        },
      );
    }
  }
}

class _UrlInputBar extends StatelessWidget {
  const _UrlInputBar({required this.controller});

  final BrowserController controller;

  static const double _actionButtonWidth = 120;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.urlController,
                  decoration: const InputDecoration(
                    hintText: 'Enter a page URL',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => controller.openCurrentUrl(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: _actionButtonWidth,
                child: FilledButton(
                  onPressed: controller.openCurrentUrl,
                  child: const Text('Open'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: _actionButtonWidth,
                child: FilledButton.icon(
                  onPressed: () async {
                    final result = await controller.processCurrentPage();
                    result.when(
                      success: (_) {},
                      failure: (error) {
                        Get.snackbar(
                          'Processing failed',
                          error.message,
                          backgroundColor: Colors.red.shade700,
                          colorText: Colors.white,
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Process'),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final isBookmarked = controller.isCurrentBookmarked.value;
                final hasUrl = controller.currentUrl.value != null;
                return IconButton(
                  tooltip:
                      isBookmarked ? 'Remove bookmark' : 'Bookmark this page',
                  icon: Icon(
                    isBookmarked ? Icons.star : Icons.star_border,
                    color: isBookmarked ? Colors.amber : null,
                  ),
                  onPressed: hasUrl
                      ? () {
                          controller.toggleBookmark();
                        }
                      : null,
                );
              }),
            ],
          ),
          Obx(() {
            final error = controller.validationError.value;
            if (error == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ExtractionPanel extends StatelessWidget {
  const _ExtractionPanel({
    required this.extractionController,
    required this.downloadController,
  });

  final ExtractionController extractionController;
  final DownloadController downloadController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            final count = extractionController.extractedItems.length;
            final selected = extractionController.selectedItems.length;
            return Text('Found $count items • Selected $selected');
          }),
        ),
        Obx(() {
          final error = extractionController.lastError.value;
          if (error == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error.message,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }),
        Expanded(
          child: Obx(() {
            final items = extractionController.extractedItems;
            if (items.isEmpty) {
              return const Center(
                child: Text('No media extracted yet.'),
              );
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _MediaListTile(
                  item: item,
                  onToggleSelected: () => extractionController.toggleSelection(item.id),
                  onDownload: () async {
                    final result = await downloadController.download(item);
                    result.when(
                      success: (downloaded) {
                        extractionController.applyDownloadedItem(downloaded);
                      },
                      failure: (error) {
                        _showDownloadError(context, error);
                      },
                    );
                  },
                  onPreview: () => _showMediaPreview(context, item),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  void _showDownloadError(BuildContext context, AppError error) {
    AppLogger.logError(
      filename: 'lib/features/browser/views/browser_view.dart',
      classname: '_ExtractionPanel',
      function: '_showDownloadError',
      systemSection: 'download',
      message: error.message,
      error: error,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download failed: ${error.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showMediaPreview(BuildContext context, MediaItem item) async {
    AppLogger.logInfo(
      filename: 'lib/features/browser/views/browser_view.dart',
      classname: '_ExtractionPanel',
      function: '_showMediaPreview',
      systemSection: 'ui',
      message: 'Opening preview for ${item.normalizedUrl}',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => _MediaPreviewDialog(item: item),
    );
  }
}

class _MediaListTile extends StatelessWidget {
  const _MediaListTile({
    required this.item,
    required this.onToggleSelected,
    required this.onDownload,
    required this.onPreview,
  });

  final MediaItem item;
  final VoidCallback onToggleSelected;
  final VoidCallback onDownload;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final downloadController = Get.find<DownloadController>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: GestureDetector(
          onTap: onPreview,
          child: _MediaThumbnail(item: item),
        ),
        title: Text(
          item.normalizedUrl.toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${item.type.name.toUpperCase()} • ${item.contentLength ?? 0} bytes'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final progress = downloadController.taskProgress[item.id];
              if (progress == null) {
                return IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Download',
                  onPressed: onDownload,
                );
              }
              switch (progress.phase) {
                case DownloadPhase.queued:
                  return const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                case DownloadPhase.inProgress:
                  return SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value:
                          progress.progress == 0 ? null : progress.progress,
                      strokeWidth: 2,
                    ),
                  );
                case DownloadPhase.completed:
                  return const Icon(Icons.check_circle, color: Colors.green);
                case DownloadPhase.failed:
                  return IconButton(
                    icon: const Icon(Icons.error, color: Colors.red),
                    tooltip: 'Retry download',
                    onPressed: onDownload,
                  );
              }
            }),
            const SizedBox(width: 8),
            Checkbox(
              value: item.isSelected,
              onChanged: (_) => onToggleSelected(),
            ),
          ],
        ),
        selected: item.isSelected,
        onTap: onPreview,
      ),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = item.thumbnailUrl ?? item.normalizedUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: item.bytes != null && item.type == MediaType.image
          ? Image.memory(
              item.bytes!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            )
          : Image.network(
              thumbnailUrl.toString(),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image),
                );
              },
            ),
    );
  }
}

class _DownloadSettingsSheet extends StatelessWidget {
  const _DownloadSettingsSheet({
    required this.settingsController,
    required this.onPickImageDirectory,
    required this.onPickVideoDirectory,
    required this.onClearImageDirectory,
    required this.onClearVideoDirectory,
  });

  final SettingsController settingsController;
  final VoidCallback onPickImageDirectory;
  final VoidCallback onPickVideoDirectory;
  final VoidCallback onClearImageDirectory;
  final VoidCallback onClearVideoDirectory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Obx(() {
          if (!settingsController.isReady.value) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final state = settingsController.state.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Download destinations',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _DirectoryTile(
                label: 'Images',
                path: state.imageSaveDirectory,
                onPick: onPickImageDirectory,
                onClear: onClearImageDirectory,
              ),
              const SizedBox(height: 12),
              _DirectoryTile(
                label: 'Videos',
                path: state.videoSaveDirectory,
                onPick: onPickVideoDirectory,
                onClear: onClearVideoDirectory,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  const _DirectoryTile({
    required this.label,
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPath = path != null && path!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label directory',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasPath ? path! : 'Not set',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasPath)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: onClear,
                      child: const Text('Clear'),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreviewDialog extends StatefulWidget {
  const _MediaPreviewDialog({required this.item});

  final MediaItem item;

  @override
  State<_MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<_MediaPreviewDialog> {
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == MediaType.video) {
      final controller = VideoPlayerController.networkUrl(
        widget.item.normalizedUrl,
      );
      _videoController = controller;
      _videoInitialization = controller.initialize();
      _videoInitialization!.then((_) {
        controller.setLooping(true);
        AppLogger.logInfo(
          filename: 'lib/features/browser/views/browser_view.dart',
          classname: '_MediaPreviewDialogState',
          function: 'initState',
          systemSection: 'ui',
          message: 'Video preview ready for ${widget.item.normalizedUrl}',
        );
        if (mounted) {
          setState(() {});
        }
      }, onError: (error, stackTrace) {
        AppLogger.logError(
          filename: 'lib/features/browser/views/browser_view.dart',
          classname: '_MediaPreviewDialogState',
          function: 'initState',
          systemSection: 'ui',
          message: 'Failed to initialize video preview for ${widget.item.normalizedUrl}',
          error: error,
          stackTrace: stackTrace,
        );
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.type == MediaType.video
                          ? 'Video preview'
                          : 'Image preview',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 360,
                width: double.infinity,
                child: _buildPreviewBody(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.normalizedUrl.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBody() {
    switch (widget.item.type) {
      case MediaType.image:
        return _buildImagePreview();
      case MediaType.video:
        return _buildVideoPreview();
      case MediaType.streaming:
        return _buildUnsupportedPreview(
          'Preview is not available for streaming media.',
        );
    }
  }

  Widget _buildImagePreview() {
    final item = widget.item;
    if (item.bytes != null) {
      return InteractiveViewer(
        child: Image.memory(
          item.bytes!,
          fit: BoxFit.contain,
        ),
      );
    }
    return InteractiveViewer(
      child: Image.network(
        item.normalizedUrl.toString(),
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          AppLogger.logError(
            filename: 'lib/features/browser/views/browser_view.dart',
            classname: '_MediaPreviewDialogState',
            function: '_buildImagePreview',
            systemSection: 'ui',
            message:
                'Failed to load image preview for ${item.normalizedUrl}',
            error: error,
            stackTrace: stackTrace,
          );
          return _buildUnsupportedPreview(
            'Unable to load image preview.',
          );
        },
      ),
    );
  }

  Widget _buildVideoPreview() {
    final controller = _videoController;
    final initialization = _videoInitialization;
    if (controller == null || initialization == null) {
      return _buildUnsupportedPreview('Video preview is unavailable.');
    }
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildUnsupportedPreview('Unable to load video preview.');
        }
        final aspectRatio = controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio;
        return Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    setState(() {
                      if (controller.value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                    });
                  },
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnsupportedPreview(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
      ),
    );
  }
}
