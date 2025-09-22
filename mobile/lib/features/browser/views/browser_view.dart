import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/result/app_result.dart';
import '../../../shared/models/media_item.dart';
import '../../download/controllers/download_controller.dart';
import '../../extract/controllers/extraction_controller.dart';
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
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _browserController = Get.find<BrowserController>();
    _extractionController = Get.find<ExtractionController>();
    _downloadController = Get.find<DownloadController>();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _browserController.isLoading.value = true;
            _browserController.currentUrl.value = Uri.tryParse(url);
          },
          onPageFinished: (url) {
            _browserController.isLoading.value = false;
            _browserController.currentUrl.value = Uri.tryParse(url);
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
          _UrlInputBar(controller: _browserController),
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
              FilledButton(
                onPressed: controller.openCurrentUrl,
                child: const Text('Open'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
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
}

class _MediaListTile extends StatelessWidget {
  const _MediaListTile({
    required this.item,
    required this.onToggleSelected,
    required this.onDownload,
  });

  final MediaItem item;
  final VoidCallback onToggleSelected;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final downloadController = Get.find<DownloadController>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _MediaThumbnail(item: item),
        title: Text(
          item.normalizedUrl.toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${item.type.name.toUpperCase()} • ${item.contentLength ?? 0} bytes'),
        trailing: Obx(() {
          final progress = downloadController.taskProgress[item.id];
          if (progress == null) {
            return IconButton(
              icon: const Icon(Icons.download),
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
                  value: progress.progress == 0 ? null : progress.progress,
                  strokeWidth: 2,
                ),
              );
            case DownloadPhase.completed:
              return const Icon(Icons.check_circle, color: Colors.green);
            case DownloadPhase.failed:
              return IconButton(
                icon: const Icon(Icons.error, color: Colors.red),
                onPressed: onDownload,
              );
          }
        }),
        selected: item.isSelected,
        onTap: onToggleSelected,
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
      child: Image.network(
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
