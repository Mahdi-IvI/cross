import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_feedback.dart';
import '../auth/presentation/auth_controller.dart';
import '../document/presentation/controllers/sync_controller.dart';
import '../document/presentation/providers/document_providers.dart';
import 'domain/scanned_page.dart';
import 'presentation/scanner_providers.dart';

class DocumentScannerPage extends ConsumerStatefulWidget {
  const DocumentScannerPage({super.key, this.parentId});
  final int? parentId;
  @override
  ConsumerState<DocumentScannerPage> createState() =>
      _DocumentScannerPageState();
}

class _DocumentScannerPageState extends ConsumerState<DocumentScannerPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(
    text: 'Scan ${DateTime.now().toIso8601String().substring(0, 10)}',
  );
  final description = TextEditingController(text: 'Scanned document');
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(activeSessionProvider) == null) return const Scaffold();
    final pages = ref.watch(scannerControllerProvider(widget.parentId));
    final controller = ref.read(
      scannerControllerProvider(widget.parentId).notifier,
    );
    ref.watch(syncControllerProvider);
    final folder = ref
        .watch(libraryProvider)
        .asData
        ?.value
        .items
        .where((item) => item.id == widget.parentId)
        .firstOrNull;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan document'),
          leading: IconButton(
            tooltip: 'Discard scan and go back',
            icon: const Icon(Icons.arrow_back),
            onPressed: busy
                ? null
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/library');
                    }
                  },
          ),
        ),
        body: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      enabled: !busy,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Document name',
                        counterText: '',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Name is required.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: description,
                      enabled: !busy,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        counterText: '',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Description is required.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Location: ${folder?.name ?? 'All files'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${pages.length} pages'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: pages.isEmpty
                  ? const Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.document_scanner_outlined, size: 64),
                              SizedBox(height: 16),
                              Text(
                                'Scan pages or import images to create a PDF.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: pages.length,
                      buildDefaultDragHandles: false,
                      onReorderItem: (from, to) {
                        if (!busy) controller.reorder(from, to);
                      },
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        return Card(
                          key: ValueKey(page.id),
                          child: ListTile(
                            leading: SizedBox(
                              width: 48,
                              height: 64,
                              child: RotatedBox(
                                quarterTurns: page.quarterTurns,
                                child: Image.file(
                                  File(page.originalPath),
                                  fit: BoxFit.contain,
                                  cacheWidth: 160,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            title: Text('Page ${index + 1}'),
                            subtitle: Text(switch (page.filter) {
                              ScanFilter.original => 'Original',
                              ScanFilter.grayscale => 'Grayscale',
                              ScanFilter.blackAndWhite => 'Black & white',
                            }),
                            onTap: busy
                                ? null
                                : () => context.push(
                                    '/scan/pages/${page.id}${widget.parentId == null ? '' : '?folder=${widget.parentId}'}',
                                  ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Remove page ${index + 1}',
                                  onPressed: busy
                                      ? null
                                      : () => perform(
                                          () => controller.remove(page.id),
                                        ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  enabled: !busy,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.drag_handle),
                                  ),
                                ),
                              ],
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
                    const Text(
                      'Leaving this screen discards the scan.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => perform(controller.capture),
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text('Scan pages'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => perform(controller.importImages),
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: const Text('Import images'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy || pages.isEmpty
                            ? null
                            : () {
                                if (!form.currentState!.validate()) return;
                                perform(() async {
                                  await controller.savePdf(
                                    name.text,
                                    description.text,
                                  );
                                  if (!context.mounted) return;
                                  unawaited(
                                    ref
                                        .read(syncControllerProvider.notifier)
                                        .synchronize(),
                                  );
                                  context.go(
                                    widget.parentId == null
                                        ? '/library'
                                        : '/library?folder=${widget.parentId}',
                                  );
                                });
                              },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          busy ? 'Preparing PDF…' : 'Save PDF & upload',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
