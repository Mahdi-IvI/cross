import '../../../../auth/presentation/auth_controller.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../../core/widgets/app_feedback.dart';
import '../../controllers/sync_controller.dart';
import '../../providers/document_providers.dart';
import '../../widgets/item_editor.dart';

class DocPropertiesPage extends ConsumerStatefulWidget {
  const DocPropertiesPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<DocPropertiesPage> createState() => _DocPropertiesPageState();
}

class _DocPropertiesPageState extends ConsumerState<DocPropertiesPage> {
  bool busy = false;
  double? progress;

  Future<void> download({required bool open}) async {
    if (busy) return;
    setState(() {
      busy = true;
      progress = null;
    });
    try {
      final path = await ref
          .read(documentActionsProvider)
          .download(
            widget.id,
            onProgress: (value) {
              if (mounted) setState(() => progress = value);
            },
          );
      if (open) {
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done) {
          throw FormatException(result.message);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Available offline on this device.')),
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(activeSessionProvider) == null) return const Scaffold();
    final snapshot = ref.watch(libraryProvider);
    ref.watch(syncControllerProvider);
    final items = snapshot.asData?.value.items ?? [];
    final item = items
        .where((item) => item.id == widget.id && !item.isFolder)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document details'),
        actions: [
          if (item != null)
            IconButton(
              tooltip: item.isFavorite ? 'Remove favorite' : 'Add favorite',
              onPressed: () async {
                try {
                  await ref
                      .read(documentActionsProvider)
                      .toggleFavorite(item.id);
                } catch (error) {
                  if (context.mounted) showError(context, error);
                }
              },
              icon: Icon(item.isFavorite ? Icons.star : Icons.star_border),
            ),
        ],
      ),
      body: snapshot.isLoading
          ? const Center(child: CircularProgressIndicator())
          : item == null
          ? const Center(child: Text('This document is no longer available.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.description_outlined, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${item.extension} · ${formatSize(item.sizeBytes)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (item.isPending)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_upload_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.syncError.isEmpty
                                      ? 'Changes saved on this device. Waiting to synchronize.'
                                      : item.syncError,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _property('Description', item.description),
                            _property('Filename', item.fileName),
                            _property(
                              'Location',
                              items
                                      .where(
                                        (folder) => folder.id == item.parentId,
                                      )
                                      .firstOrNull
                                      ?.name ??
                                  'All files',
                            ),
                            _property(
                              'File status',
                              item.hasFile
                                  ? item.isPending
                                        ? 'Upload queued'
                                        : 'Stored on server'
                                  : 'Metadata only · no uploaded file',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (busy)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(value: progress),
                      ),
                    if (item.hasFile) ...[
                      FilledButton.icon(
                        onPressed: busy ? null : () => download(open: true),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          item.availableOffline
                              ? 'Open saved file'
                              : 'Download & open',
                        ),
                      ),
                      if (!item.availableOffline)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => download(open: false),
                            icon: const Icon(Icons.offline_pin_outlined),
                            label: const Text('Save for offline'),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final result = await showItemEditor(
                                context,
                                item: item,
                                folders: items
                                    .where((item) => item.isFolder)
                                    .toList(),
                              );
                              if (result == null || !context.mounted) return;
                              try {
                                await ref
                                    .read(documentActionsProvider)
                                    .update(
                                      item.id,
                                      result.name,
                                      result.description,
                                      result.parentId,
                                    );
                                if (mounted) {
                                  unawaited(
                                    ref
                                        .read(syncControllerProvider.notifier)
                                        .synchronize(),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) showError(context, error);
                              }
                            },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit / move'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              if (!await confirmDelete(context, item) ||
                                  !context.mounted) {
                                return;
                              }
                              try {
                                await ref
                                    .read(documentActionsProvider)
                                    .delete(item.id);
                                if (!context.mounted) return;
                                unawaited(
                                  ref
                                      .read(syncControllerProvider.notifier)
                                      .synchronize(),
                                );
                                context.pop();
                              } catch (error) {
                                if (context.mounted) showError(context, error);
                              }
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete document'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _property(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SelectableText(value),
      ],
    ),
  );
}
