import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_controller.dart';
import 'domain/scanned_page.dart';
import 'presentation/scanner_providers.dart';

class EditPhotoPage extends ConsumerStatefulWidget {
  const EditPhotoPage({super.key, required this.pageId, this.parentId});
  final int? parentId;
  final String pageId;
  @override
  ConsumerState<EditPhotoPage> createState() => _EditPhotoPageState();
}

class _EditPhotoPageState extends ConsumerState<EditPhotoPage> {
  ScannedPage? page;
  Future<String>? preview;
  @override
  void initState() {
    super.initState();
    page = ref
        .read(scannerControllerProvider(widget.parentId))
        .where((page) => page.id == widget.pageId)
        .firstOrNull;
    if (page != null) {
      preview = ref
          .read(scannerControllerProvider(widget.parentId).notifier)
          .preview(page!);
    }
  }

  void apply() {
    ref
        .read(scannerControllerProvider(widget.parentId).notifier)
        .updatePage(page!);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        widget.parentId == null ? '/scan' : '/scan?folder=${widget.parentId}',
      );
    }
  }

  void change(ScannedPage updated) => setState(() {
    page = updated;
    preview = ref
        .read(scannerControllerProvider(widget.parentId).notifier)
        .preview(updated);
  });

  @override
  Widget build(BuildContext context) {
    if (ref.watch(activeSessionProvider) == null) return const Scaffold();
    ref.watch(scannerControllerProvider(widget.parentId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit scanned page'),
        actions: [
          TextButton(
            onPressed: page == null ? null : apply,
            child: const Text('Apply'),
          ),
        ],
      ),
      body: page == null
          ? const Center(child: Text('This page is no longer available.'))
          : Column(
              children: [
                Expanded(
                  child: FutureBuilder<String>(
                    future: preview,
                    builder: (context, result) {
                      if (result.hasError) {
                        return const Center(
                          child: Text(
                            'Preview unavailable. Try another image or remove this page.',
                          ),
                        );
                      }
                      if (!result.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: InteractiveViewer(
                          child: Center(
                            child: Image.file(
                              File(result.data!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<ScanFilter>(
                          segments: const [
                            ButtonSegment(
                              value: ScanFilter.original,
                              label: Text('Original'),
                            ),
                            ButtonSegment(
                              value: ScanFilter.grayscale,
                              label: Text('Gray'),
                            ),
                            ButtonSegment(
                              value: ScanFilter.blackAndWhite,
                              label: Text('B&W'),
                            ),
                          ],
                          selected: {page!.filter},
                          onSelectionChanged: (value) =>
                              change(page!.copyWith(filter: value.single)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Rotate left',
                              onPressed: () => change(
                                page!.copyWith(
                                  quarterTurns: page!.quarterTurns - 1,
                                ),
                              ),
                              icon: const Icon(Icons.rotate_left),
                            ),
                            const Text('Rotate page'),
                            IconButton(
                              tooltip: 'Rotate right',
                              onPressed: () => change(
                                page!.copyWith(
                                  quarterTurns: page!.quarterTurns + 1,
                                ),
                              ),
                              icon: const Icon(Icons.rotate_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
