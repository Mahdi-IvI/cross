import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/widgets/app_feedback.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/entities/library_item.dart';
import '../../domain/entities/upload_source.dart';
import '../controllers/sync_controller.dart';
import '../providers/document_providers.dart';
import '../providers/upload_providers.dart';
import '../widgets/doc_card.dart';
import '../widgets/item_editor.dart';

class DocumentPage extends ConsumerStatefulWidget {
  const DocumentPage({super.key, this.folderId, this.view = 'all'});
  final int? folderId;
  final String view;
  @override
  ConsumerState<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends ConsumerState<DocumentPage>
    with WidgetsBindingObserver {
  String search = '';
  String sort = 'name';
  bool grid = false;
  bool searchEverywhere = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncControllerProvider.notifier).synchronize();
    }
  }

  @override
  void didUpdateWidget(covariant DocumentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderId != widget.folderId ||
        oldWidget.view != widget.view) {
      search = '';
    }
  }

  void navigate(int? folder) =>
      context.go(folder == null ? '/library' : '/library?folder=$folder');

  Future<void> edit(List<LibraryItem> items, [LibraryItem? item]) async {
    final result = await showItemEditor(
      context,
      item: item,
      parentId: widget.folderId,
      folders: items.where((item) => item.isFolder).toList(),
    );
    if (result == null || !mounted) return;
    await perform(() async {
      final repository = ref.read(documentActionsProvider);
      if (item == null) {
        await repository.createFolder(
          result.name,
          result.description,
          result.parentId,
        );
      } else {
        await repository.update(
          item.id,
          result.name,
          result.description,
          result.parentId,
        );
      }
      unawaited(ref.read(syncControllerProvider.notifier).synchronize());
    });
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

  Future<void> action(
    ItemAction action,
    LibraryItem item,
    List<LibraryItem> items,
  ) async {
    switch (action) {
      case ItemAction.edit:
        await edit(items, item);
      case ItemAction.delete:
        if (await confirmDelete(context, item) && mounted) {
          await perform(() async {
            await ref.read(documentActionsProvider).delete(item.id);
            unawaited(ref.read(syncControllerProvider.notifier).synchronize());
          });
        }
      case ItemAction.favorite:
        await perform(
          () => ref.read(documentActionsProvider).toggleFavorite(item.id),
        );
      case ItemAction.offline:
        await perform(() async {
          final path = await ref
              .read(documentActionsProvider)
              .download(item.id);
          if (item.availableOffline) {
            final result = await OpenFilex.open(path);
            if (result.type != ResultType.done && mounted) {
              showError(context, FormatException(result.message));
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File saved for offline use.')),
            );
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(activeSessionProvider) == null) return const Scaffold();
    final library = ref.watch(libraryProvider);
    final sync = ref.watch(syncControllerProvider);
    final items = library.asData?.value.items ?? const <LibraryItem>[];
    final current = items
        .where((item) => item.id == widget.folderId && item.isFolder)
        .firstOrNull;
    final title = widget.view == 'favorites'
        ? 'Favorites'
        : current?.name ?? 'All files';
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final selectedIndex = widget.view == 'favorites' ? 1 : 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: widget.folderId == null
            ? null
            : IconButton(
                tooltip: 'Parent folder',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => navigate(current?.parentId),
              ),
        actions: [
          IconButton(
            tooltip: 'Account and settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: true,
              selectedIndex: selectedIndex,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'DOCUMENTS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              onDestinationSelected: (index) => context.go(
                index == 0 ? '/library' : '/library?view=favorites',
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: Text('All files'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.star_border),
                  selectedIcon: Icon(Icons.star),
                  label: Text('Favorites'),
                ),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                if (sync.isRunning || busy)
                  LinearProgressIndicator(
                    value: busy ? null : sync.progress,
                    minHeight: 3,
                  ),
                if (sync.error != null ||
                    (library.asData?.value.pendingCount ?? 0) > 0)
                  _statusBanner(sync, library.asData?.value.pendingCount ?? 0),
                Expanded(
                  child: library.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text(error.toString())),
                    data: (snapshot) {
                      if (widget.folderId != null && current == null) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('This folder is no longer available.'),
                              TextButton(
                                onPressed: () => navigate(null),
                                child: const Text('Back to all files'),
                              ),
                            ],
                          ),
                        );
                      }
                      return _contents(items, current, title);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => context.go(
                index == 0 ? '/library' : '/library?view=favorites',
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Files',
                ),
                NavigationDestination(
                  icon: Icon(Icons.star_border),
                  selectedIcon: Icon(Icons.star),
                  label: 'Favorites',
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => _showCreate(items),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }

  Widget _statusBanner(SyncState sync, int pending) => Material(
    color: sync.isOffline
        ? const Color(0xFFFFF2D7)
        : Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            sync.isOffline
                ? Icons.cloud_off_outlined
                : Icons.cloud_upload_outlined,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sync.error ??
                  '$pending ${pending == 1 ? 'change' : 'changes'} waiting to synchronize',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: sync.isRunning
                ? null
                : () => ref.read(syncControllerProvider.notifier).synchronize(),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _contents(
    List<LibraryItem> items,
    LibraryItem? current,
    String title,
  ) {
    final query = search.toLowerCase().trim();
    final filtered =
        items.where((item) {
          if (widget.view == 'favorites' && !item.isFavorite) return false;
          if (widget.view == 'all' &&
              !(searchEverywhere && query.isNotEmpty) &&
              item.parentId != widget.folderId) {
            return false;
          }
          return query.isEmpty ||
              '${item.name} ${item.description} ${item.fileName}'
                  .toLowerCase()
                  .contains(query);
        }).toList()..sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          if (sort == 'size') {
            return (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
          }
          return sort == 'descending'
              ? b.name.toLowerCase().compareTo(a.name.toLowerCase())
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    final path = <LibraryItem>[];
    var cursor = current;
    final visited = <int>{};
    while (cursor != null && visited.add(cursor.id)) {
      path.insert(0, cursor);
      cursor = items
          .where((item) => item.isFolder && item.id == cursor!.parentId)
          .firstOrNull;
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(syncControllerProvider.notifier).synchronize(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (path.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => navigate(null),
                            child: const Text('All files'),
                          ),
                          for (final folder in path) ...[
                            const Icon(Icons.chevron_right, size: 16),
                            TextButton(
                              onPressed: () => navigate(folder.id),
                              child: Text(folder.name),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (current?.description.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(current!.description),
                    ),
                  TextField(
                    key: ValueKey('${widget.folderId}:${widget.view}'),
                    onChanged: (value) => setState(() => search = value),
                    decoration: const InputDecoration(
                      hintText: 'Search files and folders',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${filtered.length} ${filtered.length == 1 ? 'item' : 'items'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Sort files',
                        initialValue: sort,
                        onSelected: (value) => setState(() => sort = value),
                        icon: const Icon(Icons.sort),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'name',
                            child: Text('Name: A–Z'),
                          ),
                          PopupMenuItem(
                            value: 'descending',
                            child: Text('Name: Z–A'),
                          ),
                          PopupMenuItem(
                            value: 'size',
                            child: Text('Size: largest first'),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: grid ? 'List view' : 'Grid view',
                        onPressed: () => setState(() => grid = !grid),
                        icon: Icon(
                          grid
                              ? Icons.view_list_outlined
                              : Icons.grid_view_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (search.isNotEmpty && widget.view == 'all')
                    FilterChip(
                      label: const Text('Search all folders'),
                      selected: searchEverywhere,
                      onSelected: (value) =>
                          setState(() => searchEverywhere = value),
                    ),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        query.isNotEmpty ? Icons.search_off : Icons.folder_open,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: .6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        query.isNotEmpty
                            ? 'No matching items'
                            : 'A little room to organize',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.view == 'favorites'
                            ? 'Star a file or folder to keep it close.'
                            : query.isNotEmpty
                            ? 'Try a different name or description.'
                            : 'Upload a document or create your first folder.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (filtered.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: grid
                  ? SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 250,
                            mainAxisExtent: 180,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (_, index) => _card(filtered[index], items),
                    )
                  : SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, index) => _card(filtered[index], items),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _card(LibraryItem item, List<LibraryItem> items) => DocCard(
    item: item,
    grid: grid,
    onTap: () => item.isFolder
        ? navigate(item.id)
        : context.push('/documents/${item.id}'),
    onAction: (selected) => action(selected, item, items),
  );

  Future<void> chooseUpload(UploadKind kind) => perform(() async {
    final owner = ref.read(activeSessionProvider);
    final parentId = widget.folderId;
    final source = await ref.read(uploadSourcePickerProvider).pick(kind);
    if (source == null) return;
    if (!mounted || ref.read(activeSessionProvider)?.token != owner?.token) {
      await source.dispose();
      return;
    }
    try {
      await context.push<void>(
        Uri(
          path: '/upload',
          queryParameters: {if (parentId != null) 'folder': '$parentId'},
        ).toString(),
        extra: source,
      );
    } catch (_) {
      await source.dispose();
      rethrow;
    }
  });

  Future<void> _showCreate(List<LibraryItem> items) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Scan document'),
                subtitle: const Text('Scan pages and create a PDF'),
                onTap: () => Navigator.pop(context, 'scan'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, 'photo'),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record video'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photo library'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Upload document'),
                subtitle: const Text('Choose a file to upload'),
                onTap: () => Navigator.pop(context, 'upload'),
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('Create folder'),
                onTap: () => Navigator.pop(context, 'folder'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'folder') await edit(items);
    if (choice == 'scan' && mounted) {
      context.push(
        widget.folderId == null ? '/scan' : '/scan?folder=${widget.folderId}',
      );
    }
    final kind = switch (choice) {
      'upload' => UploadKind.file,
      'photo' => UploadKind.photo,
      'video' => UploadKind.video,
      'gallery' => UploadKind.gallery,
      _ => null,
    };
    if (kind != null && mounted) await chooseUpload(kind);
  }
}
