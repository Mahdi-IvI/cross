import '../../../../core/database/app_database.dart';
import '../../../../core/database/entities/cached_item.dart';
import '../../../../core/database/entities/pending_operation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../objectbox.g.dart';
import '../../domain/entities/library_item.dart';
import '../models/document_model.dart';

class DocumentLocalDatasource {
  DocumentLocalDatasource(this.database, this.scope);
  final AppDatabase database;
  final String scope;

  List<CachedItem> all({bool includeDeleted = false}) {
    final query = database.items.query(CachedItem_.scope.equals(scope)).build();
    try {
      return query
          .find()
          .where((item) => includeDeleted || !item.isDeleted)
          .toList();
    } finally {
      query.close();
    }
  }

  CachedItem get(int id) {
    final item = database.items.get(id);
    if (item == null || item.scope != scope) {
      throw const AppFailure('This item is no longer available.');
    }
    return item;
  }

  List<PendingOperation> pending() {
    final query = database.operations
        .query(PendingOperation_.scope.equals(scope))
        .build();
    try {
      return query.find()..sort((a, b) => a.id.compareTo(b.id));
    } finally {
      query.close();
    }
  }

  Stream<LibrarySnapshot> watch() => database.items
      .query(CachedItem_.scope.equals(scope))
      .watch(triggerImmediately: true)
      .map(
        (query) => LibrarySnapshot(
          items: query
              .find()
              .where((item) => !item.isDeleted)
              .map((item) => item.toDomain())
              .toList(),
          pendingCount: pending().length,
        ),
      );

  void enqueue(CachedItem item, String action) {
    final previous = pending()
        .where((operation) => operation.itemId == item.id)
        .firstOrNull;
    if (previous == null) {
      database.operations.put(
        PendingOperation(scope: scope, itemId: item.id, action: action),
      );
    } else if (action == 'delete') {
      previous.action = action;
      database.operations.put(previous);
    }
    item.isPending = true;
    item.syncError = '';
    database.items.put(item);
  }

  void remove(CachedItem item) {
    database.operations.removeMany(
      pending().where((op) => op.itemId == item.id).map((op) => op.id).toList(),
    );
    database.items.remove(item.id);
  }

  void merge(List<RemoteItem> remote) {
    database.store.runInTransaction(TxMode.write, () {
      final existing = all(includeDeleted: true);
      final byServer = {
        for (final item in existing.where((i) => i.serverId != null))
          '${item.isFolder}:${item.serverId}': item,
      };
      // Allocate stable local IDs before resolving parent references, independent of API ordering.
      for (final source in remote) {
        final item =
            byServer[source.key] ??
            CachedItem(
              scope: scope,
              serverId: source.id,
              isFolder: source.isFolder,
              name: source.name,
              description: source.description,
            );
        if (!item.isPending) {
          item.name = source.name;
          item.description = source.description;
          item.fileName = source.fileName;
          item.sizeBytes = source.sizeBytes;
          item.hasFile = source.hasFile;
        }
        database.items.put(item);
        byServer[source.key] = item;
      }
      for (final source in remote) {
        final item = byServer[source.key]!;
        if (!item.isPending) {
          item.parentId = source.parentId == null
              ? null
              : byServer['true:${source.parentId}']?.id;
          database.items.put(item);
        }
      }
      final remoteKeys = remote.map((item) => item.key).toSet();
      for (final item in existing) {
        if (item.serverId != null &&
            !item.isPending &&
            !remoteKeys.contains('${item.isFolder}:${item.serverId}')) {
          database.items.remove(item.id);
        }
      }
    });
  }
}
