import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../../../../core/database/entities/cached_item.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../objectbox.g.dart';
import '../../domain/entities/library_item.dart';
import '../../domain/entities/item_details.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_local_datasource.dart';
import '../datasources/document_remote_datasource.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({
    required this.local,
    required this.remote,
    required this.filesDirectory,
  });
  final DocumentLocalDatasource local;
  final DocumentRemoteDatasource remote;
  final Directory filesDirectory;
  Future<void> _tail = Future.value();
  Future<void>? _sync;

  // Serialize writes with synchronization, so edits made during an upload cannot be overwritten.
  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Stream<LibrarySnapshot> watch() => local.watch();

  void _validateParent(int? parentId, {int? itemId}) {
    final visited = <int>{?itemId};
    while (parentId != null) {
      if (!visited.add(parentId)) {
        throw const AppFailure(
          'A folder cannot be moved inside itself or a descendant.',
        );
      }
      final parent = local.get(parentId);
      if (!parent.isFolder || parent.isDeleted) {
        throw const AppFailure('Choose an existing folder.');
      }
      parentId = parent.parentId;
    }
  }

  @override
  Future<int> createFolder(String name, String description, int? parentId) =>
      _locked(() async {
        final details = ItemDetails(name, description);
        _validateParent(parentId);
        final item = CachedItem(
          scope: local.scope,
          isFolder: true,
          name: details.name,
          description: details.description,
          parentId: parentId,
        );
        local.database.store.runInTransaction(TxMode.write, () {
          local.database.items.put(item);
          local.enqueue(item, 'createFolder');
        });
        return item.id;
      });

  @override
  Future<int> upload(
    String sourcePath,
    String fileName,
    String name,
    String description,
    int? parentId,
  ) => _locked(() async {
    final details = ItemDetails(name, description);
    _validateParent(parentId);
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const AppFailure('The selected file is no longer available.');
    }
    final length = await source.length();
    if (length == 0) {
      throw const AppFailure('Choose a non-empty file.');
    }
    fileName = p.basename(fileName.replaceAll('\\', '/'));
    if (fileName.trim().isEmpty ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.contains(RegExp(r'[\x00-\x1f]'))) {
      throw const AppFailure('Choose a file with a valid filename.');
    }
    await filesDirectory.create(recursive: true);
    final item = CachedItem(
      scope: local.scope,
      isFolder: false,
      name: details.name,
      description: details.description,
      parentId: parentId,
      fileName: fileName,
      sizeBytes: length,
      hasFile: true,
    );
    // Copy before committing the item and outbox together; a crash cannot expose an unqueued upload.
    final target = p.join(
      filesDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0xFFFFFFFF)}${_extension(fileName)}',
    );
    try {
      await source.copy(target);
      item.localPath = target;
      local.database.store.runInTransaction(TxMode.write, () {
        local.database.items.put(item);
        local.enqueue(item, 'upload');
      });
    } catch (_) {
      local.database.items.remove(item.id);
      await _deleteFile(target);
      rethrow;
    }
    return item.id;
  });

  @override
  Future<void> update(int id, String name, String description, int? parentId) =>
      _locked(() async {
        final item = local.get(id);
        if (item.isDeleted) {
          throw const AppFailure('This item has been deleted.');
        }
        final details = ItemDetails(name, description);
        _validateParent(parentId, itemId: item.isFolder ? id : null);
        item.name = details.name;
        item.description = details.description;
        item.parentId = parentId;
        local.database.store.runInTransaction(
          TxMode.write,
          () => local.enqueue(item, 'update'),
        );
      });

  @override
  Future<void> delete(int id) => _locked(() async {
    final root = local.get(id);
    final all = local.all(includeDeleted: true);
    final ids = <int>{id};
    // Descendants are found from local parent IDs, including unsynchronized folders.
    var changed = true;
    while (changed) {
      changed = false;
      for (final item in all) {
        if (ids.contains(item.parentId) && ids.add(item.id)) changed = true;
      }
    }
    final deleted = all.where((item) => ids.contains(item.id)).toList();
    if (deleted.isEmpty) deleted.add(root);
    local.database.store.runInTransaction(TxMode.write, () {
      for (final item in deleted) {
        if (item.serverId == null) {
          local.remove(item);
        } else {
          item.isDeleted = true;
          local.enqueue(item, 'delete');
        }
      }
    });
    for (final item in deleted) {
      await _deleteFile(item.localPath);
    }
  });

  @override
  Future<void> toggleFavorite(int id) => _locked(() async {
    final item = local.get(id);
    item.isFavorite = !item.isFavorite;
    local.database.items.put(item);
  });

  @override
  Future<void> synchronize({void Function(double?)? onProgress}) {
    return _sync ??= _locked(() => _synchronize(onProgress))
        .whenComplete(() => _sync = null);
  }

  Future<void> _synchronize(void Function(double?)? onProgress) async {
    AppFailure? firstError;
    // Create parents first, then files/edits. Deletions run from the deepest item to the root.
    final operations = local.pending();
    int depth(CachedItem item) {
      var value = 0;
      final visited = <int>{};
      while (item.parentId != null && visited.add(item.parentId!)) {
        final parent = local.database.items.get(item.parentId!);
        if (parent == null) break;
        item = parent;
        value++;
      }
      return value;
    }

    operations.sort((a, b) {
      final ai = local.get(a.itemId), bi = local.get(b.itemId);
      final ap = a.action == 'delete'
          ? 2
          : a.action == 'createFolder'
          ? 0
          : 1;
      final bp = b.action == 'delete'
          ? 2
          : b.action == 'createFolder'
          ? 0
          : 1;
      if (ap != bp) return ap.compareTo(bp);
      final byDepth = a.action == 'delete'
          ? depth(bi).compareTo(depth(ai))
          : depth(ai).compareTo(depth(bi));
      return byDepth == 0 ? a.id.compareTo(b.id) : byDepth;
    });
    for (final operation in operations) {
      final item = local.get(operation.itemId);
      try {
        if (operation.action == 'delete') {
          await remote.delete(item);
          local.database.store.runInTransaction(
            TxMode.write,
            () => local.remove(item),
          );
        } else {
          final parent = item.parentId == null
              ? null
              : local.get(item.parentId!);
          if (parent != null && parent.serverId == null) {
            throw const AppFailure(
              'Waiting for the parent folder to synchronize.',
            );
          }
          final saved = await remote.save(
            item,
            parent?.serverId,
            operation.action,
            onProgress: onProgress,
          );
          item.serverId = saved.id;
          item.fileName = saved.fileName;
          item.sizeBytes = saved.sizeBytes;
          item.hasFile = saved.hasFile;
          item.isPending = false;
          item.syncError = '';
          local.database.store.runInTransaction(TxMode.write, () {
            local.database.operations.remove(operation.id);
            local.database.items.put(item);
          });
        }
      } catch (error) {
        final failure = ApiClient.failure(error);
        item.syncError = failure.message;
        local.database.items.put(item);
        if (failure.isOffline ||
            failure.statusCode == 401 ||
            (failure.statusCode ?? 0) >= 500) {
          throw failure;
        }
        firstError ??= failure;
      }
    }
    try {
      final remoteItems = await remote.fetchAll();
      final before = local.all(includeDeleted: true);
      local.merge(remoteItems);
      final retained = local
          .all(includeDeleted: true)
          .map((item) => item.id)
          .toSet();
      for (final removed in before.where(
        (item) => !retained.contains(item.id),
      )) {
        await _deleteFile(removed.localPath);
      }
    } catch (error) {
      throw ApiClient.failure(error);
    }
    if (firstError != null) throw firstError;
  }

  String _filePath(CachedItem item) {
    return p.join(
      filesDirectory.path,
      '${item.id}${_extension(item.fileName)}',
    );
  }

  String _extension(String fileName) {
    var extension = p.extension(fileName);
    if (!RegExp(r'^\.[a-zA-Z0-9]{1,12}$').hasMatch(extension)) {
      extension = '.bin';
    }
    return extension;
  }

  @override
  Future<String> download(int id, {void Function(double)? onProgress}) =>
      _locked(() async {
        final item = local.get(id);
        if (item.isDeleted || item.isFolder || !item.hasFile) {
          throw const AppFailure('This item has no uploaded file.');
        }
        if (item.localPath.isNotEmpty && await File(item.localPath).exists()) {
          return item.localPath;
        }
        if (item.serverId == null) {
          throw const AppFailure(
            'The local upload file is missing. Select the file again.',
          );
        }
        await filesDirectory.create(recursive: true);
        final target = _filePath(item);
        final temporary = '$target.part';
        try {
          await remote.download(item, temporary, onProgress);
          if (item.sizeBytes != null &&
              await File(temporary).length() != item.sizeBytes) {
            throw const AppFailure('The download is incomplete. Please retry.');
          }
          await File(temporary).rename(target);
          item.localPath = target;
          local.database.items.put(item);
          return target;
        } catch (error) {
          await _deleteFile(temporary);
          throw ApiClient.failure(error);
        }
      });

  @override
  Future<void> removeOfflineFiles() => _locked(() async {
    final uploads = local
        .pending()
        .where((op) => op.action == 'upload')
        .map((op) => op.itemId)
        .toSet();
    for (final item in local.all(includeDeleted: true)) {
      if (!uploads.contains(item.id) && item.localPath.isNotEmpty) {
        await _deleteFile(item.localPath);
        item.localPath = '';
        local.database.items.put(item);
      }
    }
  });

  Future<void> _deleteFile(String path) async {
    if (path.isNotEmpty && await File(path).exists()) await File(path).delete();
  }
}
